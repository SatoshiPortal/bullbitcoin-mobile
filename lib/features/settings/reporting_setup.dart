import 'package:preferences/preferences.dart';
import 'package:bull_reporting/bull_reporting.dart';

Future<void> refreshReportingConsent(Preferences settings) async {
  Report.consent = ((await settings.fetch()).fold(
    (value) => value,
    (failure) => throw Exception('Preferences read failed'),
  )).isErrorReportingEnabled;
}
