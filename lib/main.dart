import 'dart:convert' show utf8;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:device_preview_plus/device_preview_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:momentum_energy/bar_chart.dart';
import 'package:momentum_energy/my_theme_model.dart';
import 'package:momentum_energy/screenshots_mobile.dart'
    if (dart.library.io) 'package:momentum_energy/screenshots_mobile.dart'
    if (dart.library.js) 'package:momentum_energy/screenshots_other.dart';
import 'package:momentum_energy/tariffs.dart';
import 'package:momentum_energy/utils.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    DevicePreview(
      enabled: !kReleaseMode && kIsWeb,
      builder: (context) => ChangeNotifierProvider(
        create: (context) => MyThemeModel(),
        child: const MyApp(),
      ), // Wrap your app
      tools: !kReleaseMode && kIsWeb
          ? [...DevicePreview.defaultTools, simpleScreenShotModesPlugin]
          : [],
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  @override
  initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MyThemeModel>(
      builder: (context, themeModel, child) {
        return MaterialApp(
          title: 'Momentum Energy Dashboard',
          // Create space for camera cut-outs etc
          useInheritedMediaQuery: true,
          // Hide the dev banner
          debugShowCheckedModeBanner: false,
          // For DevicePreview
          locale: DevicePreview.locale(context),
          builder: DevicePreview.appBuilder,

          theme: ThemeData.light().copyWith(
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: Color(0xFFA7A7A7), fontSize: 13),
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: Color(0xFFA7A7A7), fontSize: 13),
            ),
          ),
          themeMode: themeModel.currentTheme(),
          home: const HomePage(),
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  late String rawData = loading;

  final List<ListItem> _dropdownItems = [
    ListItem(1, "Recent Days"),
    ListItem(2, "Combined Days"),
    ListItem(3, "Weekly Usage"),
  ];
  late List<DropdownMenuItem<ListItem>> _dropdownMenuItems;
  late ListItem _dropdownItemSelected;
  // Bumped when tariffs change so the chart grid re-parses with new rates.
  int _tariffsRevision = 0;

  @override
  initState() {
    super.initState();
    _dropdownMenuItems = buildDropDownMenuItems(_dropdownItems);
    _dropdownItemSelected = _dropdownMenuItems[0].value!;
    _loadTariffs();
    _loadDefaultFile();
  }

  void _loadTariffs() async {
    await tariffs.load();
    if (!mounted) return;
    setState(() {
      _tariffsRevision++;
    });
  }

  void _loadDefaultFile() async {
    //print('_loadDefaultFile');
    String data = await rootBundle.loadString('assets/Your_Usage_List.csv');
    //print('data=$data');
    setState(() {
      rawData = data;
    });
  }

  void _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.any,
      //allowedExtensions: ['csv'],
      allowMultiple: false,
      allowCompression: false,
    );
    if (result != null && result.files.first.bytes != null) {
      // Momentum exports are UTF-8; fromCharCodes treated the bytes as UTF-16.
      String data = utf8.decode(result.files.first.bytes!, allowMalformed: true);
      //print('_pickFile');
      //print('data=$data');
      setState(() {
        rawData = data;
      });
    } else {
      // User canceled the picker
      setState(() {
        rawData = cancelled;
      });

      // Wait then load the template again
      Future.delayed(const Duration(milliseconds: 2000), () {
        _loadDefaultFile();
      });
    }
  }

  Future<void> _showTariffDialog(BuildContext context) async {
    final controllers = {
      'Daily supply (\$/day)': TextEditingController(text: tariffs.daily.toStringAsFixed(4)),
      'Controlled load (\$/kWh)':
          TextEditingController(text: tariffs.controlled.toStringAsFixed(4)),
      'Off peak (\$/kWh)': TextEditingController(text: tariffs.offPeak.toStringAsFixed(4)),
      'Shoulder (\$/kWh)': TextEditingController(text: tariffs.shoulder.toStringAsFixed(4)),
      'Peak (\$/kWh)': TextEditingController(text: tariffs.peak.toStringAsFixed(4)),
    };
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tariff rates'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: controllers.entries
                  .map((e) => TextField(
                        controller: e.value,
                        decoration: InputDecoration(labelText: e.key),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final values = controllers.values
                    .map((c) => double.tryParse(c.text.trim()))
                    .toList();
                if (values.any((v) => v == null || v < 0)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Rates must be non-negative numbers, e.g. 0.2992')));
                  return;
                }
                tariffs.daily = values[0]!;
                tariffs.controlled = values[1]!;
                tariffs.offPeak = values[2]!;
                tariffs.shoulder = values[3]!;
                tariffs.peak = values[4]!;
                tariffs.save();
                Navigator.pop(context);
                setState(() {
                  _tariffsRevision++;
                });
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  List<DropdownMenuItem<ListItem>> buildDropDownMenuItems(List listItems) {
    List<DropdownMenuItem<ListItem>> items = [];
    for (ListItem listItem in listItems) {
      items.add(
        DropdownMenuItem(
          value: listItem,
          child: Text(
            listItem.name,
            style: const TextStyle(color: Colors.white),
          ),
          //onTap: () => setState(() {}),
        ),
      );
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    //print("build");

    AutoSizeGroup bottomButtonGroup = AutoSizeGroup();

    return Consumer<MyThemeModel>(
      builder: (context, themeModel, child) {
        return Scaffold(
          backgroundColor: themeModel.isDark() ? const Color(0xFF20202A) : Colors.white,
          resizeToAvoidBottomInset: true,
          extendBody: true,
          extendBodyBehindAppBar: false,
          primary: true,
          body: Stack(
            children: [
              OrientationBuilder(builder: (context, orientation) {
                return LayoutBuilder(builder: (context, constraints) {
                  return SafeArea(
                    minimum: EdgeInsets.only(
                        left: orientation == Orientation.portrait ? 6 : 4,
                        right: orientation == Orientation.portrait ? 2 : 2,
                        top: 0,
                        bottom: 0),
                    bottom: false,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            AutoSizeText.rich(
                              TextSpan(
                                text: orientation == Orientation.portrait &&
                                        constraints.maxWidth <= 360
                                    ? 'Momentum Dashboard'
                                    : 'Momentum Energy Dashboard',
                                style: TextStyle(
                                  color: themeModel.isDark() ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                                children: [
                                  const TextSpan(text: '\n(Click '),
                                  TextSpan(
                                    text: orientation == Orientation.portrait &&
                                            constraints.maxWidth <= 360
                                        ? '\'Export table\''
                                        : '\'Export table\' from MyAccount',
                                    style: TextStyle(
                                        color: Theme.of(context).textTheme.labelSmall?.color ??
                                            Colors.blueAccent,
                                        height: 1.5),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        Utils.launchURI(Uri(
                                          scheme: 'https',
                                          host: 'www.momentumenergy.com.au',
                                          path: '/myaccount/my-usage',
                                        ));
                                      },
                                  ),
                                  orientation == Orientation.portrait
                                      ? const TextSpan(
                                          text: '\nThen ', style: TextStyle(height: 1.5))
                                      : const TextSpan(text: ', Then '),
                                  TextSpan(
                                    text: 'Select File',
                                    style: TextStyle(
                                        color: Theme.of(context).textTheme.labelSmall?.color ??
                                            Colors.blueAccent),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        _pickFile();
                                      },
                                  ),
                                  const TextSpan(text: ')'),
                                ],
                              ),
                            ),
                            const Spacer(flex: 10),
                            // Switch(
                            //   value: themeModel.isDark(),
                            //   onChanged: (newValue) {
                            //     Provider.of<MyThemeModel>(context, listen: false)
                            //         .switchTheme();
                            //   },
                            // ),
                            IconButton(
                              icon: const Icon(Icons.settings, size: 18),
                              tooltip: 'Tariff rates',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _showTariffDialog(context),
                            ),
                            DropdownButtonHideUnderline(
                              child: DropdownButton(
                                  dropdownColor: const Color(0xFF20202A),
                                  value: _dropdownItemSelected,
                                  items: _dropdownMenuItems,
                                  onChanged: (ListItem? value) {
                                    //print("value=${value!.name}");
                                    setState(() {
                                      _dropdownItemSelected = value!;
                                    });
                                  }),
                            ),
                          ],
                        ),
                        Expanded(
                          child: GridView.count(
                            // Ensure that widget state changes with dropdown or
                            // tariff changes (charts cache their parsed data)
                            key: Key('${_dropdownItemSelected.name}-$_tariffsRevision'),
                            crossAxisCount: constraints.maxWidth < 710 ? 1 : 2,
                            semanticChildCount: 2,
                            childAspectRatio: 2.34,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4,
                            children: _dropdownItemSelected.value == _dropdownItems[0].value
                                ? [
                                    MyCard(
                                      child: BarChartWidget1(
                                        rawData,
                                        'Last Day Use',
                                        const Duration(days: 1),
                                        ending: const Duration(days: 0),
                                        prices: false,
                                      ),
                                    ),
                                    MyCard(
                                        child: BarChartWidget1(
                                            rawData, 'Last Day Cost', const Duration(days: 1),
                                            ending: const Duration(days: 0), prices: true)),
                                    MyCard(
                                        child: BarChartWidget1(
                                            rawData, '1 Before Use', const Duration(days: 1),
                                            ending: const Duration(days: 1), prices: false)),
                                    MyCard(
                                        child: BarChartWidget1(
                                            rawData, '1 Before Cost', const Duration(days: 1),
                                            ending: const Duration(days: 1), prices: true)),
                                    MyCard(
                                        child: BarChartWidget1(
                                            rawData, '2 Before Use', const Duration(days: 1),
                                            ending: const Duration(days: 2), prices: false)),
                                    MyCard(
                                        child: BarChartWidget1(
                                            rawData, '2 Before Cost', const Duration(days: 1),
                                            ending: const Duration(days: 2), prices: true)),
                                    MyCard(
                                        child: BarChartWidget1(
                                            rawData, '3 Before Use', const Duration(days: 1),
                                            ending: const Duration(days: 3), prices: false)),
                                    MyCard(
                                        child: BarChartWidget1(
                                            rawData, '3 Before Cost', const Duration(days: 1),
                                            ending: const Duration(days: 3), prices: true)),
                                    MyCard(
                                        child: BarChartWidget1(
                                            rawData, '4 Before Use', const Duration(days: 1),
                                            ending: const Duration(days: 4), prices: false)),
                                    MyCard(
                                        child: BarChartWidget1(
                                            rawData, '4 Before Cost', const Duration(days: 1),
                                            ending: const Duration(days: 4), prices: true)),
                                    MyCard(
                                        child: BarChartWidget1(
                                            rawData, '5 Before Use', const Duration(days: 1),
                                            ending: const Duration(days: 5), prices: false)),
                                    MyCard(
                                        child: BarChartWidget1(
                                            rawData, '5 Before Cost', const Duration(days: 1),
                                            ending: const Duration(days: 5), prices: true)),
                                    MyCard(
                                        child: BarChartWidget1(
                                            rawData, '6 Before Use', const Duration(days: 1),
                                            ending: const Duration(days: 6), prices: false)),
                                    MyCard(
                                        child: BarChartWidget1(
                                            rawData, '6 Before Cost', const Duration(days: 1),
                                            ending: const Duration(days: 6), prices: true)),
                                  ]
                                : _dropdownItemSelected.value == _dropdownItems[1].value
                                    ? [
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData, '1 Days Use', const Duration(days: 1),
                                                prices: false)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData, '1 Days Cost', const Duration(days: 1),
                                                prices: true)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData, '2 Days Use', const Duration(days: 2),
                                                prices: false)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData, '2 Days Cost', const Duration(days: 2),
                                                prices: true)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData, '7 Days Use', const Duration(days: 7),
                                                prices: false)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData, '7 Days Cost', const Duration(days: 7),
                                                prices: true)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData, '14 Days Use', const Duration(days: 14),
                                                prices: false)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData, '14 Days Cost', const Duration(days: 14),
                                                prices: true)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData, '21 Days Use', const Duration(days: 21),
                                                prices: false)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData, '21 Days Cost', const Duration(days: 21),
                                                prices: true)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData, '28 Days Use', const Duration(days: 28),
                                                prices: false)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData, '28 Days Cost', const Duration(days: 28),
                                                prices: true)),
                                      ]
                                    : [
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData, 'This Week Use', const Duration(days: 7),
                                                ending: const Duration(days: 0), prices: false)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData, 'This Week Cost', const Duration(days: 7),
                                                ending: const Duration(days: 0), prices: true)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData, '1 Week Ago Use', const Duration(days: 7),
                                                ending: const Duration(days: 7), prices: false)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData, '1 Week Ago Cost', const Duration(days: 7),
                                                ending: const Duration(days: 7), prices: true)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData, '2 Weeks Ago Use', const Duration(days: 7),
                                                ending: const Duration(days: 14), prices: false)),
                                        MyCard(
                                            child: BarChartWidget1(rawData, '2 Weeks Ago Cost',
                                                const Duration(days: 7),
                                                ending: const Duration(days: 14), prices: true)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData, '3 Weeks Ago Use', const Duration(days: 7),
                                                ending: const Duration(days: 21), prices: false)),
                                        MyCard(
                                            child: BarChartWidget1(rawData, '3 Weeks Ago Cost',
                                                const Duration(days: 7),
                                                ending: const Duration(days: 21), prices: true)),

                                        //MyCard(child: BarChartWidget2()),
                                        //const MyCard(child: LineChartWidget1()),
                                        //MyCard(child: LineChartWidget2()),
                                      ],
                          ),
                        ),
                        SafeArea(
                          top: false,
                          bottom: true,
                          left: false,
                          right: false,
                          child: Container(
                          color: themeModel.isDark() ? const Color(0xFF20202A) : Colors.white,
                          width: double.infinity,
                          height: 30,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () {
                                    Utils.launchURI(Uri(
                                      scheme: 'https',
                                      host: 'github.com',
                                      path: '/bradrushworth/momentumenergy',
                                    ));
                                  },
                                  // Constrains AutoSizeText to the width of the Row
                                  child: AutoSizeText('Source Code',
                                      maxLines: 1, softWrap: false, group: bottomButtonGroup),
                                ),
                              ),
                              const MyDivider(),
                              Expanded(
                                // Constrains AutoSizeText to the width of the Row
                                child: TextButton(
                                  onPressed: () {
                                    Utils.launchURI(Uri(
                                      scheme: 'https',
                                      host: 'pub.dev',
                                      path: '/packages/fl_chart',
                                    ));
                                  },
                                  child: AutoSizeText('Chart Library',
                                      maxLines: 1, softWrap: false, group: bottomButtonGroup),
                                ),
                              ),
                              const MyDivider(),
                              kIsWeb && kReleaseMode
                                  ? Expanded(
                                      // Constrains AutoSizeText to the width of the Row
                                      child: TextButton(
                                        onPressed: () {
                                          Utils.launchURI(Uri(
                                            scheme: 'https',
                                            host: 'www.buymeacoffee.com',
                                            path: '/bitbot',
                                          ));
                                        },
                                        child: AutoSizeText('Buy Coffee',
                                            maxLines: 1,
                                            softWrap: true,
                                            overflow: TextOverflow.visible,
                                            group: bottomButtonGroup),
                                      ),
                                    )
                                  : Expanded(
                                      // Constrains AutoSizeText to the width of the Row
                                      child: TextButton(
                                        onPressed: () {
                                          Utils.launchURI(Uri(
                                            scheme: 'https',
                                            host: 'www.bitbot.com.au',
                                            path: '/',
                                          ));
                                        },
                                        child: AutoSizeText('Visit BitBot',
                                            maxLines: 1,
                                            softWrap: true,
                                            overflow: TextOverflow.visible,
                                            group: bottomButtonGroup),
                                      ),
                                    ),
                              const MyDivider(),
                              Expanded(
                                // Constrains AutoSizeText to the width of the Row
                                child: TextButton(
                                  onPressed: () {
                                    Utils.launchURI(Uri(
                                      scheme: 'mailto',
                                      path: 'bitbot@bitbot.com.au',
                                      query: 'subject=Help with Momentum Energy Dashboard',
                                    ));
                                  },
                                  child: AutoSizeText('Report Issue',
                                      maxLines: 1, softWrap: false, group: bottomButtonGroup),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ),
                      ],
                    ),
                  );
                });
              }),
            ],
          ),
        );
      },
    );
  }
}

class MyDivider extends StatelessWidget {
  const MyDivider({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      width: 1,
      color: const Color(0xFFA7A7A7),
      margin: const EdgeInsets.only(top: 2),
    );
  }
}

class MyCard extends StatelessWidget {
  final Widget child;

  const MyCard({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<MyThemeModel>(
      builder: (context, themeModel, _) {
        return Container(
          child: child,
          decoration: BoxDecoration(
              color: themeModel.isDark() ? const Color(0xFF1A1A26) : Colors.white,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  spreadRadius: 1,
                )
              ]),
        );
      },
    );
  }
}

class ListItem {
  int value;
  String name;

  ListItem(this.value, this.name);
}
