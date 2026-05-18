import 'package:bb_mobile/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../robots/onboarding_robot.dart';
import '../robots/send_robot.dart';
import '../robots/wallet_home_robot.dart';

/// Send Journey Tests
///
/// Tests the send flow UI (no actual transactions):
///   1. Navigate to send screen → shows address input
///   2. Send screen navigates away from home
///   3. Back navigation returns to home
void main() {
  patrolTest(
    'send screen shows address input',
    ($) async {
      app.main();
      final onboarding = OnboardingRobot($);
      await onboarding.expectOnboardingVisible();
      await onboarding.createWalletAndWaitForHome();

      final home = WalletHomeRobot($);
      await home.tapSend();

      final send = SendRobot($);
      await send.expectSendScreenVisible();
    },
  );

  patrolTest(
    'send navigation leaves home screen',
    ($) async {
      app.main();
      final onboarding = OnboardingRobot($);
      await onboarding.expectOnboardingVisible();
      await onboarding.createWalletAndWaitForHome();

      final home = WalletHomeRobot($);
      await home.tapSend();

      final send = SendRobot($);
      send.expectNotOnHome();
    },
  );

  patrolTest(
    'back from send returns to home',
    ($) async {
      app.main();
      final onboarding = OnboardingRobot($);
      await onboarding.expectOnboardingVisible();
      await onboarding.createWalletAndWaitForHome();

      final home = WalletHomeRobot($);
      await home.tapSend();

      final send = SendRobot($);
      await send.expectSendScreenVisible();
      await send.goBack();

      // Should be back on home screen
      await home.expectHomeVisible();
    },
  );
}
