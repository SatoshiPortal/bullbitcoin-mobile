import 'package:bb_mobile/core/utils/report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // No SharedPreferences mock is installed, so the boot-mirror write throws
  // (no platform channel) — the failure SettingsRepository swallows.
  test('an opt-out turns the live gate off even when the mirror write '
      'fails', () async {
    Report.consent = true;

    await expectLater(Report.updateConsent(false), throwsA(anything));

    // beforeSend reads this flag, so it must already be off: otherwise the
    // switch reads "off" while events keep going out for the session.
    expect(Report.consent, isFalse);
  });
}
