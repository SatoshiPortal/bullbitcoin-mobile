// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'local_data_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LocalDataLocalizationsEn extends LocalDataLocalizations {
  LocalDataLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get localDataLockedTitle => 'Unlock your device';

  @override
  String get localDataLockedMessage =>
      'Your wallet data stays sealed until this device has been unlocked once since it started. Unlock it, then try again.';

  @override
  String get localDataRetryButton => 'Try again';

  @override
  String get localDataRecoveryTitle => 'Local data cannot be opened';

  @override
  String get localDataRecoveryMainMessage =>
      'The data this app keeps on this device (your wallet list, labels, transaction history, swaps and settings) is encrypted, and the key that opens it is no longer available on this device.';

  @override
  String get localDataRecoveryPayjoinMessage =>
      'The Payjoin sessions this app keeps on this device are encrypted, and the key that opens them is no longer available on this device. Your wallets are not affected.';

  @override
  String get localDataRecoveryInconsistentMessage =>
      'Some of the data this app keeps on this device is in a state it cannot open safely.';

  @override
  String get localDataRecoveryRestoreHint =>
      'Resetting erases it. Your recovery phrase or encrypted backup restores your wallets afterwards; labels, swaps and Payjoin sessions do not come back.';

  @override
  String get localDataResetButton => 'Reset local data';

  @override
  String get localDataResetConfirmTitle => 'Erase local data?';

  @override
  String get localDataResetConfirmMessage => 'This cannot be undone.';

  @override
  String get localDataResetConfirmCheckbox =>
      'I have my recovery phrase or encrypted backup';

  @override
  String get localDataResetConfirmButton => 'Erase';

  @override
  String get localDataCancelButton => 'Cancel';

  @override
  String get localDataContactSupportButton => 'Contact support';

  @override
  String get localDataShareLogsButton => 'Share logs';

  @override
  String get localDataShareLogsFailedMessage => 'Failed to share logs';

  @override
  String get localDataResetFailedMessage =>
      'The reset did not complete. Try again.';
}
