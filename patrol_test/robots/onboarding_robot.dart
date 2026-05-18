import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_constants.dart';
import 'base_robot.dart';

/// Robot for the onboarding/splash screen shown on fresh install.
///
/// This screen appears when the app has no wallet. It offers:
///   - "Create New Wallet" → creates wallet, navigates to home
///   - "Recover Wallet" → recovery method selection
///   - "Advanced Options" → advanced setup (hardcoded, not localized)
class OnboardingRobot extends BaseRobot {
  OnboardingRobot(super.$);

  /// Verify the onboarding screen is visible with all expected elements.
  Future<void> expectOnboardingVisible() async {
    final found = await waitForText(
      TestStrings.createNewWallet,
      timeout: TestTimeouts.standard,
    );
    expect(found, isTrue, reason: 'Onboarding screen did not appear');
    assertVisible(TestStrings.recoverWallet);
    assertVisible(TestStrings.advancedOptions);
  }

  /// Tap "Create New Wallet" and wait until the home screen appears.
  ///
  /// This is the most common setup step — used by any test that needs
  /// a wallet to exist. Each Patrol test is a fresh install, so every
  /// test beyond onboarding verification must call this.
  Future<void> createWalletAndWaitForHome() async {
    await tapText(TestStrings.createNewWallet);
    await $.pump(const Duration(seconds: 2));

    final home = await waitForText(
      TestStrings.receive,
      timeout: TestTimeouts.walletCreation,
    );
    expect(home, isTrue,
        reason: 'Wallet home did not appear after wallet creation');
  }

  /// Tap "Recover Wallet" to navigate to recovery method selection.
  Future<void> tapRecoverWallet() async {
    await tapText(TestStrings.recoverWallet);
    await $.pump(const Duration(seconds: 2));
  }

  /// Tap "Advanced Options".
  Future<void> tapAdvancedOptions() async {
    await tapText(TestStrings.advancedOptions);
    await $.pump(const Duration(seconds: 2));
  }

  /// Verify the recovery method selection screen is visible.
  ///
  /// After tapping "Recover Wallet", the app shows:
  ///   - "Recover your wallet" title
  ///   - "Encrypted vault" (cloud backup)
  ///   - "Physical backup" (12-word mnemonic)
  Future<void> expectRecoveryMethodsVisible() async {
    final found = await waitForText(
      TestStrings.recoverYourWallet,
      timeout: TestTimeouts.standard,
    );

    if (!found) {
      // Fallback: check for either recovery method option
      final hasVault = await waitForText(
        TestStrings.encryptedVault,
        timeout: TestTimeouts.quick,
      );
      final hasPhysical = await waitForText(
        TestStrings.physicalBackup,
        timeout: TestTimeouts.quick,
      );
      expect(hasVault || hasPhysical, isTrue,
          reason: 'Recovery method selection did not appear');
    }
  }
}
