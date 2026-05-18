/// Localized strings used in test assertions.
///
/// All values sourced from localization/app_en.arb.
/// Single source of truth — update here when upstream l10n changes.
class TestStrings {
  TestStrings._();

  // Onboarding
  static const createNewWallet = 'Create New Wallet';
  static const recoverWallet = 'Recover Wallet';
  static const advancedOptions = 'Advanced Options'; // hardcoded, not in arb

  // Wallet home buttons
  static const receive = 'Receive';
  static const send = 'Send';

  // Default wallet card labels
  static const bitcoinWalletLabel = 'Secure Bitcoin';
  static const liquidWalletLabel = 'Instant payments';

  // Receive screen
  static const receiveTitle = 'Receive';
  static const receiveAddress = 'Receive Address';

  // Send screen
  static const sendTitle = 'Send';
  static const sendScanPrompt = 'Scan any Bitcoin';
  static const sendAddressHint = "Recipient's address or invoice";
  static const sendContinue = 'Continue';
  static const sendSelectAmount = 'Select amount';

  // Settings
  static const settingsTitle = 'Settings';

  // Recovery screen
  static const recoverYourWallet = 'Recover your wallet';
  static const encryptedVault = 'Encrypted vault';
  static const physicalBackup = 'Physical backup';
}

/// Timeouts tuned for emulator performance.
class TestTimeouts {
  TestTimeouts._();

  /// Standard wait for a widget to appear.
  static const standard = Duration(seconds: 15);

  /// Extended wait for wallet creation / heavy operations.
  static const walletCreation = Duration(seconds: 45);

  /// Quick check — widget should already be present.
  static const quick = Duration(seconds: 5);

  /// Interval between pump cycles in waitForText.
  static const pumpInterval = Duration(milliseconds: 500);
}
