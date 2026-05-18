import 'package:bb_mobile/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../robots/onboarding_robot.dart';
import '../robots/wallet_home_robot.dart';

/// Onboarding Journey Tests
///
/// Tests the first-time user experience:
///   1. Fresh install shows onboarding
///   2. Create wallet reaches home screen with wallet cards
///   3. Recover wallet shows recovery method options
void main() {
  patrolTest(
    'fresh install shows complete onboarding screen',
    ($) async {
      app.main();
      final onboarding = OnboardingRobot($);
      await onboarding.expectOnboardingVisible();
    },
  );

  patrolTest(
    'create wallet shows home with both wallet cards',
    ($) async {
      app.main();
      final onboarding = OnboardingRobot($);
      await onboarding.expectOnboardingVisible();
      await onboarding.createWalletAndWaitForHome();

      final home = WalletHomeRobot($);
      await home.expectHomeVisible();
      await home.expectWalletCards();
    },
  );

  patrolTest(
    'recover wallet shows recovery method selection',
    ($) async {
      app.main();
      final onboarding = OnboardingRobot($);
      await onboarding.expectOnboardingVisible();
      await onboarding.tapRecoverWallet();
      await onboarding.expectRecoveryMethodsVisible();
    },
  );
}
