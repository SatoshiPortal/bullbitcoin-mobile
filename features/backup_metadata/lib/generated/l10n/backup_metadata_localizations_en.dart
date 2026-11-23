// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'backup_metadata_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class BackupMetadataLocalizationsEn extends BackupMetadataLocalizations {
  BackupMetadataLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get dataBackup => 'Data backup';

  @override
  String get intro =>
      'BULL keeps an encrypted copy of your wallet data up to date after every change, so you can get it back on a new phone.';

  @override
  String get whatIsSaved => 'What is saved';

  @override
  String get labels => 'Labels';

  @override
  String get labelsDescription =>
      'Your notes on transactions, addresses and coins, and which coins are frozen.';

  @override
  String get neverRecoveryPhrase => 'Never your recovery phrase';

  @override
  String get physicalBackup =>
      'Keep your physical backup: without the wallet, this copy can’t be opened.';

  @override
  String get whoCanRead => 'Who can read it';

  @override
  String get privacy =>
      'Encrypted on this phone. Anyone with the wallet’s recovery phrase or its public key (xpub) can open it.';

  @override
  String get where => 'Where';

  @override
  String get googleDrive => 'Google Drive';

  @override
  String get iCloud => 'iCloud';

  @override
  String get customLocation => 'Custom location';

  @override
  String get driveDescription => 'Hidden app folder of your Google account';

  @override
  String get iCloudDescription => 'Your iCloud Drive, in BULL’s folder';

  @override
  String get folderDescription =>
      'A folder you choose: phone, SD card, USB drive or another app';

  @override
  String get continueAction => 'Continue';

  @override
  String get walletsTitle => 'Wallets to back up';

  @override
  String get walletsIntro =>
      'One encrypted file per recovery phrase. Each one opens only with that wallet.';

  @override
  String get testBackup => 'Test it';

  @override
  String get turnOn => 'Turn on backup';

  @override
  String get unverified =>
      'Physical backup not tested. Keep it available to recover this wallet.';

  @override
  String get publicKeyWarning =>
      'Opens with its public key. Apps or servers that know it could read these labels.';

  @override
  String get unsupported => 'This wallet is not supported.';

  @override
  String get wallets => 'Wallets';

  @override
  String get upToDate => 'Up to date';

  @override
  String get actionNeeded => 'Action needed';

  @override
  String get backUpNow => 'Back up now';

  @override
  String get destination => 'Destination';

  @override
  String get restoreFromBackup => 'Restore from backup';

  @override
  String get turnOff => 'Turn off';

  @override
  String get turnOffTitle => 'Turn off automatic backup?';

  @override
  String get turnOffMessage =>
      'New changes will stay on this phone. To also delete existing backups created by this phone, select the option below.';

  @override
  String get alsoDelete => 'Also delete the backups';

  @override
  String get cancel => 'Cancel';

  @override
  String get restorePrompt => 'Restore your labels?';

  @override
  String get restorePromptMessage =>
      'If automatic data backup was on, your labels and frozen coins can come back. BULL looks for the backup of this wallet only.';

  @override
  String get lookInDrive => 'Look in Google Drive';

  @override
  String get lookInICloud => 'Look in iCloud';

  @override
  String get chooseFile => 'Choose a backup file';

  @override
  String get notNow => 'Not now';

  @override
  String get restoreLater => 'You can do it later in Backup › Data backup.';

  @override
  String get restoreLabels => 'Restore labels';

  @override
  String get version => 'Version';

  @override
  String get changesTitle => 'What changes on this phone';

  @override
  String get labelsToAdd => 'Labels to add';

  @override
  String get coinsToFreeze => 'Coins to freeze';

  @override
  String get alreadySame => 'Already the same';

  @override
  String get different => 'Different on this phone';

  @override
  String get nothingDeleted => 'Nothing on this phone is deleted.';

  @override
  String get restore => 'Restore';

  @override
  String get labelsRestored => 'Labels restored';

  @override
  String get restorePartial => 'Restore partially completed';

  @override
  String freezePending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count coins have not been discovered yet.',
      one: '1 coin has not been discovered yet.',
    );
    return '$_temp0';
  }

  @override
  String freezeFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count coins could not be frozen.',
      one: '1 coin could not be frozen.',
    );
    return '$_temp0';
  }

  @override
  String get retryFreezes => 'Retry freezing coins';

  @override
  String get done => 'Done';

  @override
  String get enableAfterRestore => 'Turn on automatic backup';

  @override
  String get failureNotReady =>
      'Open BULL and try again after it finishes starting.';

  @override
  String get failureStalePlan =>
      'Your labels changed. Review the backup again before restoring.';

  @override
  String get failureTooLarge => 'This backup is too large.';

  @override
  String get failureUnexpected => 'Something went wrong. Please try again.';

  @override
  String privacyProvider(String provider) {
    return '$provider can’t open it without those credentials.';
  }

  @override
  String backUpWallet(String wallet) {
    return 'Back up $wallet';
  }

  @override
  String unattributedLabels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count labels without a wallet are not backed up.',
      one: '1 label without a wallet is not backed up.',
    );
    return '$_temp0';
  }

  @override
  String changesWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes waiting',
      one: '1 change waiting',
    );
    return '$_temp0';
  }

  @override
  String reconnect(String provider) {
    return 'Reconnect $provider';
  }

  @override
  String walletCount(int selected, int total) {
    return '$selected of $total';
  }

  @override
  String foundIn(String provider) {
    return 'Found in $provider';
  }

  @override
  String keepLabel(String label) {
    return 'Keep « $label »';
  }

  @override
  String useBackupLabel(String label) {
    return 'Use backup « $label »';
  }

  @override
  String restoredAmounts(int labels, int coins) {
    String _temp0 = intl.Intl.pluralLogic(
      labels,
      locale: localeName,
      other: '$labels labels',
      one: '1 label',
    );
    String _temp1 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coins coins frozen',
      one: '1 coin frozen',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String pendingAmounts(int labels, int coins) {
    String _temp0 = intl.Intl.pluralLogic(
      labels,
      locale: localeName,
      other: '$labels labels',
      one: '1 label',
    );
    String _temp1 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coins coins pending',
      one: '1 coin pending',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String labelsRejected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count labels could not be restored.',
      one: '1 label could not be restored.',
    );
    return '$_temp0';
  }

  @override
  String differencesResolved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count differences resolved as you chose.',
      one: '1 difference resolved as you chose.',
    );
    return '$_temp0';
  }

  @override
  String handedTo(String provider, String when) {
    return 'Handed to $provider $when';
  }

  @override
  String pendingStatus(String when) {
    return 'Saved as soon as the phone is online. Last backup $when.';
  }

  @override
  String reconnectStatus(String provider, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes are kept',
      one: '1 change is kept',
    );
    return 'BULL can’t reach $provider anymore. $_temp0 on this phone until you reconnect.';
  }

  @override
  String labelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count labels',
      one: '1 label',
    );
    return '$_temp0';
  }

  @override
  String previousVersionKept(String labels) {
    return '$labels · previous version kept';
  }

  @override
  String latestVersion(String date) {
    return 'Latest · $date';
  }

  @override
  String previousVersion(String date) {
    return 'Previous · $date';
  }

  @override
  String get sameRecoveryPhrase => 'Same recovery phrase';

  @override
  String get importedPhrase => 'Imported phrase';

  @override
  String get watchOnly => 'Watch-only';

  @override
  String get off => 'Off';

  @override
  String recentStatus(String when) {
    return 'Up to date · $when';
  }
}
