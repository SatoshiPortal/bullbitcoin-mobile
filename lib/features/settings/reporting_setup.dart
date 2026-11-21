import 'package:preferences/preferences.dart';
import 'package:bull_reporting/bull_reporting.dart';

Future<void> refreshReportingConsent(SettingsRepository settings) async {
  Report.consent = (await settings.fetch()).isErrorReportingEnabled;
}
