import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'local_data_localizations_en.dart';
import 'local_data_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of LocalDataLocalizations
/// returned by `LocalDataLocalizations.of(context)`.
///
/// Applications need to include `LocalDataLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/local_data_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: LocalDataLocalizations.localizationsDelegates,
///   supportedLocales: LocalDataLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the LocalDataLocalizations.supportedLocales
/// property.
abstract class LocalDataLocalizations {
  LocalDataLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static LocalDataLocalizations of(BuildContext context) {
    return Localizations.of<LocalDataLocalizations>(
      context,
      LocalDataLocalizations,
    )!;
  }

  static const LocalizationsDelegate<LocalDataLocalizations> delegate =
      _LocalDataLocalizationsDelegate();

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

  /// Title shown when the device keystore is locked at startup
  ///
  /// In en, this message translates to:
  /// **'Unlock your device'**
  String get localDataLockedTitle;

  /// Explains that the device must be unlocked before the app can open its data
  ///
  /// In en, this message translates to:
  /// **'Your wallet data stays sealed until this device has been unlocked once since it started. Unlock it, then try again.'**
  String get localDataLockedMessage;

  /// Button to try opening the local data again
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get localDataRetryButton;

  /// Title shown when an encrypted local database cannot be opened
  ///
  /// In en, this message translates to:
  /// **'Local data cannot be opened'**
  String get localDataRecoveryTitle;

  /// Explains that the main local database cannot be decrypted on this device
  ///
  /// In en, this message translates to:
  /// **'The data this app keeps on this device (your wallet list, labels, transaction history, swaps and settings) is encrypted, and the key that opens it is no longer available on this device.'**
  String get localDataRecoveryMainMessage;

  /// Explains that the Payjoin database cannot be decrypted on this device
  ///
  /// In en, this message translates to:
  /// **'The Payjoin sessions this app keeps on this device are encrypted, and the key that opens them is no longer available on this device. Your wallets are not affected.'**
  String get localDataRecoveryPayjoinMessage;

  /// Explains that RecoverBull local metadata is unavailable
  ///
  /// In en, this message translates to:
  /// **'RecoverBull\'s local backup data cannot be opened safely on this device.'**
  String get localDataRecoveryRecoverbullMessage;

  /// Explains exactly what a consented RecoverBull reset removes and preserves
  ///
  /// In en, this message translates to:
  /// **'Resetting removes local backup verification, monitoring history and alerts. Your wallets and exported encrypted backups are kept. Legacy server settings and permission may be imported again.'**
  String get localDataRecoveryRecoverbullRestoreHint;

  /// Explains that local database files are in a state the app cannot open safely
  ///
  /// In en, this message translates to:
  /// **'Some of the data this app keeps on this device is in a state it cannot open safely.'**
  String get localDataRecoveryInconsistentMessage;

  /// What a reset erases and how wallets are restored afterwards
  ///
  /// In en, this message translates to:
  /// **'Resetting erases it. Your recovery phrase or encrypted backup restores your wallets afterwards; labels, swaps and Payjoin sessions do not come back.'**
  String get localDataRecoveryRestoreHint;

  /// Button that starts the reset of the unreadable local data
  ///
  /// In en, this message translates to:
  /// **'Reset local data'**
  String get localDataResetButton;

  /// Title of the reset confirmation sheet
  ///
  /// In en, this message translates to:
  /// **'Erase local data?'**
  String get localDataResetConfirmTitle;

  /// Warning in the reset confirmation sheet
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get localDataResetConfirmMessage;

  /// Checkbox the user must tick before erasing local data
  ///
  /// In en, this message translates to:
  /// **'I have my recovery phrase or encrypted backup'**
  String get localDataResetConfirmCheckbox;

  /// Button that erases the local data after confirmation
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get localDataResetConfirmButton;

  /// Button that closes the reset confirmation without erasing
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get localDataCancelButton;

  /// Button to contact support
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get localDataContactSupportButton;

  /// Button to share the app logs
  ///
  /// In en, this message translates to:
  /// **'Share logs'**
  String get localDataShareLogsButton;

  /// Shown when sharing logs failed
  ///
  /// In en, this message translates to:
  /// **'Failed to share logs'**
  String get localDataShareLogsFailedMessage;

  /// Shown when the reset of local data failed
  ///
  /// In en, this message translates to:
  /// **'The reset did not complete. Try again.'**
  String get localDataResetFailedMessage;
}

class _LocalDataLocalizationsDelegate
    extends LocalizationsDelegate<LocalDataLocalizations> {
  const _LocalDataLocalizationsDelegate();

  @override
  Future<LocalDataLocalizations> load(Locale locale) {
    return SynchronousFuture<LocalDataLocalizations>(
      lookupLocalDataLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_LocalDataLocalizationsDelegate old) => false;
}

LocalDataLocalizations lookupLocalDataLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return LocalDataLocalizationsEn();
    case 'fr':
      return LocalDataLocalizationsFr();
  }

  throw FlutterError(
    'LocalDataLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
