import 'package:bb_mobile/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../robots/onboarding_robot.dart';
import '../robots/receive_robot.dart';
import '../robots/wallet_home_robot.dart';

/// Receive Journey Tests
///
/// Tests the receive flow after wallet creation:
///   1. Navigate to receive screen → shows QR code
///   2. Receive screen displays a wallet address
///   3. Back navigation returns to home
void main() {
  patrolTest(
    'receive screen shows address and QR area',
    ($) async {
      app.main();
      final onboarding = OnboardingRobot($);
      await onboarding.expectOnboardingVisible();
      await onboarding.createWalletAndWaitForHome();

      final home = WalletHomeRobot($);
      await home.tapReceive();

      final receive = ReceiveRobot($);
      await receive.expectReceiveScreenVisible();

      // Verify an address is actually generated and displayed
      final hasAddress = await receive.hasAddressDisplayed();
      expect(hasAddress, isTrue,
          reason: 'No wallet address displayed on receive screen');
    },
  );

  patrolTest(
    'receive screen shows QR display widget',
    ($) async {
      app.main();
      final onboarding = OnboardingRobot($);
      await onboarding.expectOnboardingVisible();
      await onboarding.createWalletAndWaitForHome();

      final home = WalletHomeRobot($);
      await home.tapReceive();

      final receive = ReceiveRobot($);
      await receive.expectReceiveScreenVisible();

      // Verify the QR display widget is present (was orphaned — never called before)
      await receive.expectQrDisplayVisible();
    },
  );

  patrolTest(
    'back from receive returns to home',
    ($) async {
      app.main();
      final onboarding = OnboardingRobot($);
      await onboarding.expectOnboardingVisible();
      await onboarding.createWalletAndWaitForHome();

      final home = WalletHomeRobot($);
      await home.tapReceive();

      final receive = ReceiveRobot($);
      await receive.expectReceiveScreenVisible();
      await receive.goBack();

      // Should be back on home screen
      await home.expectHomeVisible();
    },
  );
}
