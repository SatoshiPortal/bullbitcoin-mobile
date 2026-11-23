import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wizard/wizard.dart';

import 'test_branding.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a completed wizard does not render again', () async {
    SharedPreferences.setMockInitialValues({'wizard_completed_version': 1});
    final wizard = WizardFeature.mount();
    expect(
      await wizard.runIfNeeded(
        notificationChannelId: 'payments',
        exchangeAllowed: false,
        branding: testBranding,
      ),
      isA<Ok<void, WizardFailure>>(),
    );
  });

  for (final consent in [null, false, true]) {
    test('preserves pending reporting consent $consent before init', () async {
      SharedPreferences.setMockInitialValues({
        'wizard_pending_version': 1,
        'wizard_pending_currency': 'CAD',
        if (consent != null) 'wizard_pending_error_reporting': consent,
      });
      expect(
        await WizardFeature.mount().readReportingConsent(),
        isA<Ok<bool?, WizardFailure>>().having(
          (result) => result.value,
          'consent',
          consent,
        ),
      );
    });
  }
}
