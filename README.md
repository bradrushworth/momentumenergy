[Visualise your Momentum Energy electricity consumption](https://momentumenergy.codemagic.app/)
using this flutter dashboard. Just download your usage file (
e.g.&nbsp;`Your_Usage_List_202201071739166144.csv`) with the longest time period that suits you,
from the [MyAccount Portal](https://www.momentumenergy.com.au/myaccount/my-usage) and then upload it
to the app with the _Upload File_ link. The file stays locally on your device/computer and is
processed by your browser.

If you are having problems downloading CSV files from Momentum Energy, where the file is empty other
than a single error message, please try using a shorter time period. The export feature appears to
be very unreliable and unfortunately there is nothing I can do about it. Try to keep the export to
only a small number of weeks.

[![Dashboard Example Screenshot](assets/screenshot.png)](https://momentumenergy.codemagic.app/)

[Momentum Energy Dashboard](https://momentumenergy.codemagic.app/) is not affiliated
with [Momentum Energy](https://www.momentumenergy.com.au/) other than we are a customer of their
electricity services. The name Momentum Energy is their trademark.

Feel free to [buy Brad a coffee](https://www.buymeacoffee.com/bitbot) if you thought this dashboard
was great. Feedback welcome too.

## About the data and charts

Momentum Energy provides usage as a downloadable CSV (the *MyAccount Portal*
export), with one row every 5 minutes. You upload that file in the app and it
is parsed and aggregated **locally on your device** — the file is never sent to
a server.

Regardless of the 5-minute source interval, the dashboard draws the charts as
**fixed half-hour bars**: 2 bars per hour, 48 bars per day. For the 5 minute
data, its six 5-minute intervals are **summed into each half-hour bar**, so one
bar shows the total of 6 x 5-minute kWh (or cost) values. This aggregation is
implemented in `DataAggregator.aggregateData` in `lib/bar_chart.dart`, where
each reading is bucketed with `graphPos = date.hour * 2 + date.minute ~/ 30`.

## Development

This is a standard Flutter project.

- Install dependencies: `flutter pub get`
- Run the tests: `flutter test` (the aggregation logic, including the 5-minute
  into half-hour bar summing, is covered in `test/bar_chart_test.dart`)
- Static analysis: `flutter analyze`

The chart aggregation lives in `lib/bar_chart.dart` (`DataAggregator`) and the
screens are assembled in `lib/main.dart`.

## Building and deploying

There is no local deploy script. Builds and releases are automated with
[Codemagic](https://momentumenergy.codemagic.app/). Pushing to the `master`
branch triggers the Codemagic pipeline, which builds and publishes the web,
Android and iOS versions.

## Versioning

The version is defined in `pubspec.yaml` as `version: x.y.z+build`
(e.g. `1.3.1+18`).

