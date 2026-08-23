import 'dart:collection';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:momentum_energy/tariffs.dart';

const int METER_INTERVAL = 5; // minutes

// Default rates, kept for tests/backwards-compatibility; the live values are
// user-adjustable via Settings and read from `tariffs` (see tariffs.dart).
const double DAILY = 2.1109; // Daily charge
const double CONTROLLED = 0.1771; // Controlled
const double OFFPEAK = 0.2992; // Off peak
const double SHOULDER = 0.3971; // Shoulder
const double PEAK = 0.4620; // Peak

final List<Color> colors = [
  const Color(0xFF5974FF),
  const Color(0xFFFF3E8D),
  Colors.lightGreen,
  Colors.orange,
  Colors.red,
  Colors.blueAccent,
];

class BarChartWidget1 extends StatefulWidget {
  // Input is PARSED rows (CsvState owns parsing now); an empty list means
  // "no data for this window" and is rendered directly by this widget rather
  // than callers juggling loading/cancelled sentinel strings.
  late List<List<dynamic>> rows;
  late int numMeters;
  late String title;
  late Duration duration;
  late Duration ending;
  final bool prices;
  final bool allowPartial;

  BarChartWidget1(this.rows, this.numMeters, this.title, this.duration,
      {Key? key,
      this.ending = const Duration(days: 0),
      this.prices = false,
      this.allowPartial = false})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => BarChartState();
}

class BarChartState extends State<BarChartWidget1> {
  // NONE of these may be `late final`. Flutter reuses a State object whenever
  // the new widget has the same runtimeType and key at the same tree
  // position, so a Cost -> Usage metric switch in the history feed hands
  // this State a brand-new BarChartWidget1 with different flags. Caching the
  // first widget's values in final fields made the chart keep drawing its
  // first metric forever (only the card's title/trailing text changed). See
  // _syncFromWidget.
  List<List<dynamic>> _rows = const [];
  int _numMeters = 1;
  String _title = '';
  Duration _duration = Duration.zero;
  Duration _ending = Duration.zero;
  bool _prices = false;
  bool _allowPartial = false;
  List<BarChartGroupData> _barChartData = [];
  Map<int, String> _barChartTitles = {};
  bool _notEnoughData = false;

  /// The `prices` flag used by the most recently completed aggregation.
  /// Exposed for the keyless metric-change regression test: it only flips
  /// once `_syncFromWidget` + `parseFile` actually ran, proving the State
  /// re-synced instead of keeping stale `late final` inputs.
  @visibleForTesting
  bool get lastParsePrices => _prices;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
    parseFile();
  }

  /// Copy every rendering input off the current widget. Returns true when
  /// any of them actually changed, i.e. when the cached aggregation is
  /// stale.
  bool _syncFromWidget() {
    final changed = _rows != widget.rows ||
        _numMeters != widget.numMeters ||
        _title != widget.title ||
        _duration != widget.duration ||
        _ending != widget.ending ||
        _prices != widget.prices ||
        _allowPartial != widget.allowPartial;
    _rows = widget.rows;
    _numMeters = widget.numMeters;
    _title = widget.title;
    _duration = widget.duration;
    _ending = widget.ending;
    _prices = widget.prices;
    _allowPartial = widget.allowPartial;
    return changed;
  }

  @override
  void didUpdateWidget(BarChartWidget1 oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-sync EVERY input (not just rows) and re-aggregate when anything
    // moved: the history feed's metric chips swap `prices` on a reused
    // State, and the window params can change with the data.
    if (_syncFromWidget()) {
      parseFile();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_rows.isEmpty) {
      return Text('No data for $_title');
    }
    return Column(
      children: _notEnoughData
          ? [
              const Spacer(),
              Text(
                'Not enough data available for:\n$_title',
                textAlign: TextAlign.center,
              ),
              const Spacer()
            ]
          : [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                  child: BarChart(
                    BarChartData(
                      barGroups: _barChartData,
                      titlesData: FlTitlesData(
                        rightTitles:
                            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles:
                            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                          reservedSize: 30,
                          showTitles: true,
                          interval: 2, // One label slot per hour (48 half-hour bars).
                          getTitlesWidget: (xValue, titleMeta) {
                            int graphPos = xValue.toInt();
                            return SideTitleWidget(
                              axisSide: AxisSide.bottom,
                              angle: 0,
                              space: 9,
                              child: Text(
                                // Every 3 hours (6 half-hour bars) horizontal.
                                graphPos % 6 == 0 ? _barChartTitles[graphPos]! : '',
                                style: const TextStyle(fontSize: 8),
                              ),
                            );
                          },
                        )),
                        leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (xValue, titleMeta) {
                                  String formattedNumber = titleMeta.max < 1
                                      ? xValue.toStringAsFixed(2)
                                      : xValue.toStringAsFixed(1);
                                  return SideTitleWidget(
                                    axisSide: AxisSide.left,
                                    child: Text(
                                      // The unit is derived here and ONLY
                                      // here.
                                      _prices ? '\$$formattedNumber' : '$formattedNumber kWh',
                                      style: const TextStyle(fontSize: 9),
                                    ),
                                  );
                                })),
                      ),
                      barTouchData: BarTouchData(
                        enabled: true,
                        handleBuiltInTouches: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, gi, rod, ri) {
                            final label = _barChartTitles[group.x] ?? '';
                            final unit = _prices ? ' \$' : ' kWh';
                            return BarTooltipItem(
                                '$label\n${rod.toY.toStringAsFixed(_prices ? 2 : 3)}$unit',
                                const TextStyle(color: Colors.white, fontSize: 11));
                          },
                        ),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                    ),
                    duration: Duration.zero,
                  ),
                ),
              ),
            ],
    );
  }

  void parseFile() {
    if (_rows.isEmpty) {
      setState(() {
        _barChartData = [];
        _barChartTitles = {};
        _notEnoughData = false;
      });
      return;
    }

    DataAggregator dataAggregator = DataAggregator(_duration, _ending, _prices,
        numMeters: _numMeters, allowPartial: _allowPartial);
    try {
      dataAggregator.aggregateData(_rows);

      setState(() {
        _barChartData = dataAggregator.newData.values.toList();
        _barChartTitles = dataAggregator.newTitles;
        _notEnoughData = false;
      });
    } on NotEnoughDataException {
      // Data exists but not enough for this particular chart.
      setState(() {
        _barChartData = [];
        _barChartTitles = {};
        _notEnoughData = true;
      });
    }
  }
}

class DataAggregator {
  final SplayTreeMap<int, BarChartGroupData> newData = SplayTreeMap<int, BarChartGroupData>();
  final SplayTreeMap<int, String> newTitles = SplayTreeMap<int, String>();

  late final Duration _duration, _ending;
  late final bool _prices;
  final int _numMeters;
  final bool _allowPartial;
  // True when every in-range record fell on a weekend; single-day weekend
  // charts then colour their bars off-peak to match how they are billed.
  bool _allWeekend = false;

  DataAggregator(this._duration, this._ending, this._prices,
      {required int numMeters, bool allowPartial = false})
      : _numMeters = numMeters,
        _allowPartial = allowPartial;

  static String dateParse(String input) {
    // e.g. 13/12/21 02:30
    return '20' +
        input.substring(6, 8) +
        input.substring(3, 5) +
        input.substring(0, 2) +
        'T' +
        input.substring(9, 11) +
        ':' +
        input.substring(12, 14) +
        ':00';
  }

  /// Meters show up as consecutive rows sharing one timestamp.
  ///
  /// The single implementation of that rule: `CsvState._parse` calls it once
  /// per file and passes the answer to every `DataAggregator` through
  /// `numMeters`, so nothing re-detects per aggregate. Returns 1 for an
  /// empty list.
  static int detectNumMeters(List<List<dynamic>> data) {
    if (data.isEmpty) return 1;
    int numMeters = 1;
    final firstDate = data.first[0];
    while (numMeters < data.length && data[numMeters][0] == firstDate) {
      numMeters++;
    }
    return numMeters;
  }

  aggregateData(List<List<dynamic>> data) {
    DateTime latest = DateTime.parse(dateParse(data.last[0]).substring(0, 8))
        .subtract(_ending)
        .add(const Duration(days: 1));
    DateTime earliest = latest.subtract(_duration);
    //print('latest=$latest earliest=$earliest');

    Map<int, double> stackedValue = {};
    Map<int, List<double>> stackedValues = {};

    bool beforeRange = false;
    bool afterRange = false;
    bool sawWeekday = false;
    bool sawWeekend = false;

    for (int n = 0; n < data.length; n += _numMeters) {
      List<dynamic> record = data[n];
      //print("adding record[0]=${record[0]}");
      DateTime date = DateTime.parse(dateParse(record[0]));
      if (date.isBefore(earliest)) {
        continue; // Skip data outside of range
      }
      if (date.isAtSameMomentAs(earliest)) {
        beforeRange = true;
      }
      if (date.isAtSameMomentAs(latest.subtract(const Duration(minutes: 30)))) {
        afterRange = true;
      }
      if (date.isAfter(latest) || date.isAtSameMomentAs(latest)) {
        continue; // Skip data outside of range
      }
      //print('Allowed date=$date');

      int graphPos = date.hour * 2 + date.minute ~/ 30;
      newTitles[graphPos] ??= _canonicalHalfHour(graphPos);

      if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
        sawWeekend = true;
      } else {
        sawWeekday = true;
      }

      for (int meterNum = 0; meterNum < _numMeters; meterNum++) {
        record = data[n + meterNum];
        //print("adding date=$date record[1]=${record[1]}");
        stackedValue[graphPos] = (stackedValue[graphPos] ?? 0.0) +
            (_prices ? _getCost(meterNum, date.weekday, graphPos, 0.0 + record[1]) : record[1]);
        stackedValues[graphPos] = (stackedValues[graphPos] ??
            List<double>.generate(_numMeters + (_prices ? 1 : 0), (index) => 0.0));
        stackedValues[graphPos]![meterNum] = (stackedValues[graphPos]![meterNum]) +
            (_prices ? _getCost(meterNum, date.weekday, graphPos, 0.0 + record[1]) : record[1]);
      }

      if (_prices) {
        double dailySupplyChargePerInterval = tariffs.daily / 24 / (60 / METER_INTERVAL);
        double dailySupplyChargePer30Mins = tariffs.daily / 24 / 2;
        stackedValue[graphPos] = stackedValue[graphPos]! + dailySupplyChargePerInterval;
        stackedValues[graphPos]![_numMeters] = dailySupplyChargePer30Mins * _duration.inDays;
      }
    }

    _allWeekend = sawWeekend && !sawWeekday;

    //print('beforeRange=$beforeRange afterRange=$afterRange');
    if (!beforeRange || !afterRange) {
      if (!_allowPartial) {
        // If there wasn't enough data to answer the questions
        throw NotEnoughDataException();
      }

      // Fill in any missing graph positions with zeros.
      for (int graphPos = 0; graphPos < 48; graphPos++) {
        stackedValue[graphPos] ??= 0.0;
        stackedValues[graphPos] ??=
            List<double>.generate(_numMeters + (_prices ? 1 : 0), (index) => 0.0);
        newTitles[graphPos] ??= _canonicalHalfHour(graphPos);
      }
    }

    for (int graphPos in stackedValue.keys) {
      //print("saving graphPos=$graphPos record[1]=${stackedValue[graphPos]}");
      newData[graphPos] = BarChartGroupData(x: graphPos, barRods: [
        makeRodData(graphPos, stackedValue[graphPos]!, stackedValues[graphPos]!.reversed.toList())
      ]);
    }
  }

  static double roundDouble(double value, int places) {
    num mod = pow(10.0, places);
    // round, not ceil: ceiling every stack segment biased totals upward.
    return ((value * mod).roundToDouble() / mod);
  }

  // Canonical per-half-hour label (00:00, 00:30, ...), derived from the bar
  // index so a filled (allowPartial) slot with no source record still gets a
  // correct label.
  static String _canonicalHalfHour(int graphPos) {
    final int h = graphPos ~/ 2;
    final int m = (graphPos % 2) * 30;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  BarChartRodData makeRodData(int graphPos, double value, List<double> stackedValues) {
    double rodCumulative = 0.0;
    int i = 0;
    //print("meterNum=$meterNum");
    return BarChartRodData(
      toY: roundDouble(value, _prices ? 2 : 3),
      // Transparent, not a colour: the rod is only a backdrop for
      // `rodStackItems`, which carry every visible segment. A solid rod
      // showed through above the stack as a grey tip.
      color: Colors.transparent,
      width: 6, // / _duration.inDays,
      //borderRadius: BorderRadius.circular(2),
      rodStackItems: stackedValues
          .map((e) => BarChartRodStackItem(rodCumulative,
              rodCumulative += roundDouble(e, _prices ? 2 : 3), _getCostColor(i++, graphPos)))
          .toList(),
    );
  }

  Color _getCostColor(int meterNum, int graphPos) {
    //print("meterNum=$meterNum graphPos=$graphPos");
    // meterNum indexes the REVERSED stack list. The controlled-load meter
    // (source meter 0) only exists on multi-meter exports and sits at the end
    // of the reversed list; on cost charts the supply segment is prepended.
    if (_numMeters > 1 &&
        (!_prices && meterNum == _numMeters - 1 || _prices && meterNum == _numMeters)) {
      return colors[1]; // Controlled
    } else if (_prices && meterNum == 0) {
      return colors[0]; // Supply
    } else if (_allWeekend) {
      return colors[2]; // Off peak (weekends are billed off-peak all day)
    } else if (graphPos < 7 * 2) {
      return colors[2]; // Off peak
    } else if (graphPos < 17 * 2) {
      return colors[3]; // Shoulder
    } else if (graphPos < 20 * 2) {
      return colors[4]; // Peak
    } else if (graphPos < 22 * 2) {
      return colors[3]; // Shoulder
    } else {
      return colors[2]; // Off peak
    }
  }

  double _getCost(int meterNum, int weekday, int graphPos, double value) {
    if (_numMeters > 1 && meterNum == 0) {
      // Meter 0 is the controlled load only when the export has a second
      // meter; a single-meter export is all general usage.
      return value * tariffs.controlled; // Controlled
    } else if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
      return value * tariffs.offPeak; // Off peak
    } else if (graphPos < 7 * 2) {
      return value * tariffs.offPeak; // Off peak
    } else if (graphPos < 17 * 2) {
      return value * tariffs.shoulder; // Shoulder
    } else if (graphPos < 20 * 2) {
      return value * tariffs.peak; // Peak
    } else if (graphPos < 22 * 2) {
      return value * tariffs.shoulder; // Shoulder
    } else {
      return value * tariffs.offPeak; // Off peak
    }
  }
}

class NotEnoughDataException implements Exception {}
