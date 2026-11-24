import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'backup_metadata_localizations_en.dart';
import 'backup_metadata_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of BackupMetadataLocalizations
/// returned by `BackupMetadataLocalizations.of(context)`.
///
/// Applications need to include `BackupMetadataLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/backup_metadata_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: BackupMetadataLocalizations.localizationsDelegates,
///   supportedLocales: BackupMetadataLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the BackupMetadataLocalizations.supportedLocales
/// property.
abstract class BackupMetadataLocalizations {
  BackupMetadataLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static BackupMetadataLocalizations of(BuildContext context) {
    return Localizations.of<BackupMetadataLocalizations>(
      context,
      BackupMetadataLocalizations,
    )!;
  }

  static const LocalizationsDelegate<BackupMetadataLocalizations> delegate =
      _BackupMetadataLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @dataBackup.
  ///
  /// In en, this message translates to:
  /// **'Data backup'**
  String get dataBackup;

  /// No description provided for @intro.
  ///
  /// In en, this message translates to:
  /// **'BULL keeps an encrypted copy of your wallet data up to date after every change, so you can get it back on a new phone.'**
  String get intro;

  /// No description provided for @whatIsSaved.
  ///
  /// In en, this message translates to:
  /// **'What is saved'**
  String get whatIsSaved;

  /// No description provided for @labels.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get labels;

  /// No description provided for @labelsDescription.
  ///
  /// In en, this message translates to:
  /// **'Your notes on transactions, addresses and coins, and which coins are frozen.'**
  String get labelsDescription;

  /// No description provided for @neverRecoveryPhrase.
  ///
  /// In en, this message translates to:
  /// **'Never your recovery phrase'**
  String get neverRecoveryPhrase;

  /// No description provided for @physicalBackup.
  ///
  /// In en, this message translates to:
  /// **'Keep your physical backup: without the wallet, this copy can’t be opened.'**
  String get physicalBackup;

  /// No description provided for @whoCanRead.
  ///
  /// In en, this message translates to:
  /// **'Who can read it'**
  String get whoCanRead;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Encrypted on this phone. Anyone with the wallet’s recovery phrase or its public key (xpub) can open it.'**
  String get privacy;

  /// No description provided for @where.
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get where;

  /// No description provided for @googleDrive.
  ///
  /// In en, this message translates to:
  /// **'Google Drive'**
  String get googleDrive;

  /// No description provided for @iCloud.
  ///
  /// In en, this message translates to:
  /// **'iCloud'**
  String get iCloud;

  /// No description provided for @customLocation.
  ///
  /// In en, this message translates to:
  /// **'Custom location'**
  String get customLocation;

  /// No description provided for @driveDescription.
  ///
  /// In en, this message translates to:
  /// **'Hidden app folder of your Google account'**
  String get driveDescription;

  /// No description provided for @iCloudDescription.
  ///
  /// In en, this message translates to:
  /// **'Your iCloud Drive, in BULL’s folder'**
  String get iCloudDescription;

  /// No description provided for @folderDescription.
  ///
  /// In en, this message translates to:
  /// **'A folder you choose: phone, SD card, USB drive or another app'**
  String get folderDescription;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @walletsTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallets to back up'**
  String get walletsTitle;

  /// No description provided for @walletsIntro.
  ///
  /// In en, this message translates to:
  /// **'One encrypted file per recovery phrase. Each one opens only with that wallet.'**
  String get walletsIntro;

  /// No description provided for @testBackup.
  ///
  /// In en, this message translates to:
  /// **'Test it'**
  String get testBackup;

  /// No description provided for @turnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on backup'**
  String get turnOn;

  /// No description provided for @unverified.
  ///
  /// In en, this message translates to:
  /// **'Physical backup not tested. Keep it available to recover this wallet.'**
  String get unverified;

  /// No description provided for @publicKeyWarning.
  ///
  /// In en, this message translates to:
  /// **'Opens with its public key. Apps or servers that know it could read these labels.'**
  String get publicKeyWarning;

  /// No description provided for @unsupported.
  ///
  /// In en, this message translates to:
  /// **'This wallet is not supported.'**
  String get unsupported;

  /// No description provided for @wallets.
  ///
  /// In en, this message translates to:
  /// **'Wallets'**
  String get wallets;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get upToDate;

  /// No description provided for @actionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Action needed'**
  String get actionNeeded;

  /// No description provided for @backUpNow.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get backUpNow;

  /// No description provided for @destination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destination;

  /// No description provided for @restoreFromBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get restoreFromBackup;

  /// No description provided for @turnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get turnOff;

  /// No description provided for @turnOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn off automatic backup?'**
  String get turnOffTitle;

  /// No description provided for @turnOffMessage.
  ///
  /// In en, this message translates to:
  /// **'New changes will stay on this phone. To also delete existing backups created by this phone, select the option below.'**
  String get turnOffMessage;

  /// No description provided for @alsoDelete.
  ///
  /// In en, this message translates to:
  /// **'Also delete the backups'**
  String get alsoDelete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @restorePrompt.
  ///
  /// In en, this message translates to:
  /// **'Restore your labels?'**
  String get restorePrompt;

  /// No description provided for @restorePromptMessage.
  ///
  /// In en, this message translates to:
  /// **'If automatic data backup was on, your labels and frozen coins can come back. BULL looks for the backup of this wallet only.'**
  String get restorePromptMessage;

  /// No description provided for @lookInDrive.
  ///
  /// In en, this message translates to:
  /// **'Look in Google Drive'**
  String get lookInDrive;

  /// No description provided for @lookInICloud.
  ///
  /// In en, this message translates to:
  /// **'Look in iCloud'**
  String get lookInICloud;

  /// No description provided for @chooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a backup file'**
  String get chooseFile;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @restoreLater.
  ///
  /// In en, this message translates to:
  /// **'You can do it later in Backup › Data backup.'**
  String get restoreLater;

  /// No description provided for @restoreLabels.
  ///
  /// In en, this message translates to:
  /// **'Restore labels'**
  String get restoreLabels;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @changesTitle.
  ///
  /// In en, this message translates to:
  /// **'What changes on this phone'**
  String get changesTitle;

  /// No description provided for @labelsToAdd.
  ///
  /// In en, this message translates to:
  /// **'Labels to add'**
  String get labelsToAdd;

  /// No description provided for @coinsToFreeze.
  ///
  /// In en, this message translates to:
  /// **'Coins to freeze'**
  String get coinsToFreeze;

  /// No description provided for @alreadySame.
  ///
  /// In en, this message translates to:
  /// **'Already the same'**
  String get alreadySame;

  /// No description provided for @different.
  ///
  /// In en, this message translates to:
  /// **'Different on this phone'**
  String get different;

  /// No description provided for @nothingDeleted.
  ///
  /// In en, this message translates to:
  /// **'Nothing on this phone is deleted.'**
  String get nothingDeleted;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @labelsRestored.
  ///
  /// In en, this message translates to:
  /// **'Labels restored'**
  String get labelsRestored;

  /// No description provided for @restorePartial.
  ///
  /// In en, this message translates to:
  /// **'Restore partially completed'**
  String get restorePartial;

  /// No description provided for @freezePending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 coin has not been discovered yet.} other{{count} coins have not been discovered yet.}}'**
  String freezePending(int count);

  /// No description provided for @freezeFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 coin could not be frozen.} other{{count} coins could not be frozen.}}'**
  String freezeFailed(int count);

  /// No description provided for @retryFreezes.
  ///
  /// In en, this message translates to:
  /// **'Retry freezing coins'**
  String get retryFreezes;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @enableAfterRestore.
  ///
  /// In en, this message translates to:
  /// **'Turn on automatic backup'**
  String get enableAfterRestore;

  /// No description provided for @failureNotReady.
  ///
  /// In en, this message translates to:
  /// **'Open BULL and try again after it finishes starting.'**
  String get failureNotReady;

  /// No description provided for @failureStalePlan.
  ///
  /// In en, this message translates to:
  /// **'Your labels changed. Review the backup again before restoring.'**
  String get failureStalePlan;

  /// No description provided for @failureTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This backup is too large.'**
  String get failureTooLarge;

  /// No description provided for @failureUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get failureUnexpected;

  /// No description provided for @privacyProvider.
  ///
  /// In en, this message translates to:
  /// **'{provider} can’t open it without those credentials.'**
  String privacyProvider(String provider);

  /// No description provided for @backUpWallet.
  ///
  /// In en, this message translates to:
  /// **'Back up {wallet}'**
  String backUpWallet(String wallet);

  /// No description provided for @unattributedLabels.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 label without a wallet is not backed up.} other{{count} labels without a wallet are not backed up.}}'**
  String unattributedLabels(int count);

  /// No description provided for @changesWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 change waiting} other{{count} changes waiting}}'**
  String changesWaiting(int count);

  /// No description provided for @reconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect {provider}'**
  String reconnect(String provider);

  /// No description provided for @walletCount.
  ///
  /// In en, this message translates to:
  /// **'{selected} of {total}'**
  String walletCount(int selected, int total);

  /// No description provided for @foundIn.
  ///
  /// In en, this message translates to:
  /// **'Found in {provider}'**
  String foundIn(String provider);

  /// No description provided for @keepLabel.
  ///
  /// In en, this message translates to:
  /// **'Keep « {label} »'**
  String keepLabel(String label);

  /// No description provided for @useBackupLabel.
  ///
  /// In en, this message translates to:
  /// **'Use backup « {label} »'**
  String useBackupLabel(String label);

  /// No description provided for @restoredAmounts.
  ///
  /// In en, this message translates to:
  /// **'{labels, plural, one{1 label} other{{labels} labels}} · {coins, plural, one{1 coin frozen} other{{coins} coins frozen}}'**
  String restoredAmounts(int labels, int coins);

  /// No description provided for @pendingAmounts.
  ///
  /// In en, this message translates to:
  /// **'{labels, plural, one{1 label} other{{labels} labels}} · {coins, plural, one{1 coin pending} other{{coins} coins pending}}'**
  String pendingAmounts(int labels, int coins);

  /// No description provided for @labelsRejected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 label could not be restored.} other{{count} labels could not be restored.}}'**
  String labelsRejected(int count);

  /// No description provided for @differencesResolved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 difference resolved as you chose.} other{{count} differences resolved as you chose.}}'**
  String differencesResolved(int count);

  /// No description provided for @handedTo.
  ///
  /// In en, this message translates to:
  /// **'Handed to {provider} {when}'**
  String handedTo(String provider, String when);

  /// No description provided for @pendingStatus.
  ///
  /// In en, this message translates to:
  /// **'Saved as soon as the phone is online. Last backup {when}.'**
  String pendingStatus(String when);

  /// No description provided for @reconnectStatus.
  ///
  /// In en, this message translates to:
  /// **'BULL can’t reach {provider} anymore. {count, plural, one{1 change is kept} other{{count} changes are kept}} on this phone until you reconnect.'**
  String reconnectStatus(String provider, int count);

  /// No description provided for @labelCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 label} other{{count} labels}}'**
  String labelCount(int count);

  /// No description provided for @previousVersionKept.
  ///
  /// In en, this message translates to:
  /// **'{labels} · previous version kept'**
  String previousVersionKept(String labels);

  /// No description provided for @latestVersion.
  ///
  /// In en, this message translates to:
  /// **'Latest · {date}'**
  String latestVersion(String date);

  /// No description provided for @previousVersion.
  ///
  /// In en, this message translates to:
  /// **'Previous · {date}'**
  String previousVersion(String date);

  /// No description provided for @sameRecoveryPhrase.
  ///
  /// In en, this message translates to:
  /// **'Same recovery phrase'**
  String get sameRecoveryPhrase;

  /// No description provided for @importedPhrase.
  ///
  /// In en, this message translates to:
  /// **'Imported phrase'**
  String get importedPhrase;

  /// No description provided for @watchOnly.
  ///
  /// In en, this message translates to:
  /// **'Watch-only'**
  String get watchOnly;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @recentStatus.
  ///
  /// In en, this message translates to:
  /// **'Up to date · {when}'**
  String recentStatus(String when);
}

class _BackupMetadataLocalizationsDelegate
    extends LocalizationsDelegate<BackupMetadataLocalizations> {
  const _BackupMetadataLocalizationsDelegate();

  @override
  Future<BackupMetadataLocalizations> load(Locale locale) {
    return SynchronousFuture<BackupMetadataLocalizations>(
      lookupBackupMetadataLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_BackupMetadataLocalizationsDelegate old) => false;
}

BackupMetadataLocalizations lookupBackupMetadataLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return BackupMetadataLocalizationsEn();
    case 'fr':
      return BackupMetadataLocalizationsFr();
  }

  throw FlutterError(
    'BackupMetadataLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
