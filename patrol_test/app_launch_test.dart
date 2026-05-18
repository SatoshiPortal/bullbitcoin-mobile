import 'package:bb_mobile/main.dart' as app;
import 'package:patrol/patrol.dart';

import 'robots/onboarding_robot.dart';

/// ============================================================
/// Bull Bitcoin Mobile — Smoke Test
/// ============================================================
///
/// Single fast health check: can the app launch and show onboarding?
/// This is the minimum viable test — if this fails, nothing else works.
///
/// Detailed user journey coverage lives in journeys/:
///   - onboarding_journey_test.dart (create wallet, recover, wallet cards)
///   - receive_journey_test.dart (QR, address, back navigation)
///   - send_journey_test.dart (address input, navigation, back)
///
/// ============================================================

void main() {
  patrolTest(
    'app launches and shows onboarding for fresh install',
    ($) async {
      app.main();
      final onboarding = OnboardingRobot($);
      await onboarding.expectOnboardingVisible();
    },
  );
}
