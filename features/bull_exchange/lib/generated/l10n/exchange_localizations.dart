import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'exchange_localizations_ar.dart';
import 'exchange_localizations_as.dart';
import 'exchange_localizations_bg.dart';
import 'exchange_localizations_bn.dart';
import 'exchange_localizations_cs.dart';
import 'exchange_localizations_de.dart';
import 'exchange_localizations_el.dart';
import 'exchange_localizations_en.dart';
import 'exchange_localizations_es.dart';
import 'exchange_localizations_fa.dart';
import 'exchange_localizations_fi.dart';
import 'exchange_localizations_fr.dart';
import 'exchange_localizations_hi.dart';
import 'exchange_localizations_hy.dart';
import 'exchange_localizations_it.dart';
import 'exchange_localizations_ka.dart';
import 'exchange_localizations_ko.dart';
import 'exchange_localizations_pt.dart';
import 'exchange_localizations_ru.dart';
import 'exchange_localizations_sw.dart';
import 'exchange_localizations_th.dart';
import 'exchange_localizations_tr.dart';
import 'exchange_localizations_uk.dart';
import 'exchange_localizations_vi.dart';
import 'exchange_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of ExchangeLocalizations
/// returned by `ExchangeLocalizations.of(context)`.
///
/// Applications need to include `ExchangeLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/exchange_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
///   supportedLocales: ExchangeLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the ExchangeLocalizations.supportedLocales
/// property.
abstract class ExchangeLocalizations {
  ExchangeLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static ExchangeLocalizations of(BuildContext context) {
    return Localizations.of<ExchangeLocalizations>(
      context,
      ExchangeLocalizations,
    )!;
  }

  static const LocalizationsDelegate<ExchangeLocalizations> delegate =
      _ExchangeLocalizationsDelegate();

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
    Locale('ar'),
    Locale('as'),
    Locale('bg'),
    Locale('bn'),
    Locale('cs'),
    Locale('de'),
    Locale('el'),
    Locale('en'),
    Locale('es'),
    Locale('fa'),
    Locale('fi'),
    Locale('fr'),
    Locale('hi'),
    Locale.fromSubtags(languageCode: 'hi', scriptCode: 'Latn'),
    Locale('hy'),
    Locale('it'),
    Locale('ka'),
    Locale('ko'),
    Locale('pt'),
    Locale('pt', 'BR'),
    Locale('ru'),
    Locale('sw'),
    Locale('th'),
    Locale('tr'),
    Locale('uk'),
    Locale('vi'),
    Locale('zh'),
  ];

  /// Label for email field in account information
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get exchangeAccountInfoEmailLabel;

  /// Label for first name field in account information
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get exchangeAccountInfoFirstNameLabel;

  /// Label for last name field in account information
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get exchangeAccountInfoLastNameLabel;

  /// Error message when account information fails to load
  ///
  /// In en, this message translates to:
  /// **'Unable to load account information'**
  String get exchangeAccountInfoLoadErrorMessage;

  /// Title for the account information section
  ///
  /// In en, this message translates to:
  /// **'Account information'**
  String get exchangeAccountInfoTitle;

  /// Success message when user number is copied to clipboard
  ///
  /// In en, this message translates to:
  /// **'User number copied to clipboard'**
  String get exchangeAccountInfoUserNumberCopiedMessage;

  /// Label for user number field in account information
  ///
  /// In en, this message translates to:
  /// **'User number'**
  String get exchangeAccountInfoUserNumberLabel;

  /// Status label for identity verified verification level
  ///
  /// In en, this message translates to:
  /// **'Identity verified'**
  String get exchangeAccountInfoVerificationIdentityVerified;

  /// Label for verification level field in account information
  ///
  /// In en, this message translates to:
  /// **'Verification level'**
  String get exchangeAccountInfoVerificationLevelLabel;

  /// Status label for light verification level
  ///
  /// In en, this message translates to:
  /// **'Light verification'**
  String get exchangeAccountInfoVerificationLightVerification;

  /// Status label for limited verification level
  ///
  /// In en, this message translates to:
  /// **'Limited verification'**
  String get exchangeAccountInfoVerificationLimitedVerification;

  /// Status label for not verified verification level
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get exchangeAccountInfoVerificationNotVerified;

  /// Label for default currency setting in exchange app settings
  ///
  /// In en, this message translates to:
  /// **'Default Currency'**
  String get exchangeAppSettingsDefaultCurrencyLabel;

  /// Description for email notifications toggle in exchange app settings
  ///
  /// In en, this message translates to:
  /// **'Receive email notifications for orders and account updates'**
  String get exchangeAppSettingsEmailNotificationsDescription;

  /// Label for email notifications toggle in exchange app settings
  ///
  /// In en, this message translates to:
  /// **'Email Notifications'**
  String get exchangeAppSettingsEmailNotificationsLabel;

  /// Label for preferred language setting in exchange app settings
  ///
  /// In en, this message translates to:
  /// **'Preferred Language'**
  String get exchangeAppSettingsPreferredLanguageLabel;

  /// Button label for saving exchange app settings
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get exchangeAppSettingsSaveButton;

  /// Success message displayed when exchange app settings are saved
  ///
  /// In en, this message translates to:
  /// **'Settings saved successfully'**
  String get exchangeAppSettingsSaveSuccessMessage;

  /// Warning message when language and currency preferences are not both set
  ///
  /// In en, this message translates to:
  /// **'Please set both language and currency preferences before saving.'**
  String get exchangeAppSettingsValidationWarning;

  /// Login error message
  ///
  /// In en, this message translates to:
  /// **'An error occurred, please try logging in again.'**
  String get exchangeAuthErrorMessage;

  /// Title for the default Bitcoin wallets section in exchange
  ///
  /// In en, this message translates to:
  /// **'Default Bitcoin Wallets'**
  String get exchangeBitcoinWalletsTitle;

  /// Shown when the exchange API could not be reached or timed out. Same wording as recipientsErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get exchangeErrorNetwork;

  /// exchange user-facing failure message (#1895).
  ///
  /// In en, this message translates to:
  /// **'Your preferences could not be saved. Please try again.'**
  String get exchangeErrorSavingPreferences;

  /// Button label for uploading files in exchange
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get exchangeFileUploadButton;

  /// Title for uploading documents in exchange
  ///
  /// In en, this message translates to:
  /// **'Upload any document'**
  String get exchangeFileUploadDocumentTitle;

  /// Instructions for uploading documents in exchange
  ///
  /// In en, this message translates to:
  /// **'If you need to send any other documents, upload them here.'**
  String get exchangeFileUploadInstructions;

  /// Status badge when files have been accepted
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get exchangeFileUploadStatusAccepted;

  /// Status badge when files are under review
  ///
  /// In en, this message translates to:
  /// **'In Review'**
  String get exchangeFileUploadStatusInReview;

  /// Short rejected-status badge shown next to a re-upload action in the secure file upload screen.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get exchangeFileUploadStatusRejectedBadge;

  /// Success message when file is uploaded successfully
  ///
  /// In en, this message translates to:
  /// **'File uploaded successfully'**
  String get exchangeFileUploadSuccess;

  /// Call-to-action shown when a rejected upload can be retried by tapping.
  ///
  /// In en, this message translates to:
  /// **'Tap to re-upload'**
  String get exchangeFileUploadTapToReupload;

  /// Title for the secure file upload section in exchange
  ///
  /// In en, this message translates to:
  /// **'Secure File Upload'**
  String get exchangeFileUploadTitle;

  /// Message with link to apply for the referral program
  ///
  /// In en, this message translates to:
  /// **'Apply to join the program here'**
  String get exchangeReferralsApplyToJoinMessage;

  /// Message prompting users to contact support about the referral program
  ///
  /// In en, this message translates to:
  /// **'Contact support to learn about our referral program'**
  String get exchangeReferralsContactSupportMessage;

  /// Title encouraging users to join the referral mission
  ///
  /// In en, this message translates to:
  /// **'Join the mission'**
  String get exchangeReferralsJoinMissionTitle;

  /// Link to the Bull Bitcoin mission page
  ///
  /// In en, this message translates to:
  /// **'bullbitcoin.com/mission'**
  String get exchangeReferralsMissionLink;

  /// Title for the referral codes section
  ///
  /// In en, this message translates to:
  /// **'Referral Codes'**
  String get exchangeReferralsTitle;

  /// Button label for accessing security settings in exchange
  ///
  /// In en, this message translates to:
  /// **'Access Settings'**
  String get exchangeSecurityAccessSettingsButton;

  /// Label for managing 2FA and password in exchange security settings
  ///
  /// In en, this message translates to:
  /// **'Manage 2FA and password'**
  String get exchangeSecurityManage2FAPasswordLabel;

  /// Title for the account information section in exchange settings
  ///
  /// In en, this message translates to:
  /// **'Account Information'**
  String get exchangeSettingsAccountInformationTitle;

  /// exchange_settings user-facing failure message (#1895).
  ///
  /// In en, this message translates to:
  /// **'A document has already been submitted.'**
  String get exchangeSettingsErrorDocumentAlreadySubmitted;

  /// exchange_settings user-facing failure message (#1895).
  ///
  /// In en, this message translates to:
  /// **'That file is empty. Choose another one.'**
  String get exchangeSettingsErrorDocumentEmpty;

  /// exchange_settings user-facing failure message (#1895).
  ///
  /// In en, this message translates to:
  /// **'That file is too large. Choose a smaller one.'**
  String get exchangeSettingsErrorDocumentTooLarge;

  /// exchange_settings user-facing failure message (#1895).
  ///
  /// In en, this message translates to:
  /// **'That file type is not accepted. Choose another one.'**
  String get exchangeSettingsErrorDocumentTypeNotAllowed;

  /// exchange_settings user-facing failure message (#1895).
  ///
  /// In en, this message translates to:
  /// **'That file could not be read. Choose another one.'**
  String get exchangeSettingsErrorDocumentUnreadable;

  /// exchange_settings user-facing failure message (#1895).
  ///
  /// In en, this message translates to:
  /// **'Your account details could not be loaded. Please try again.'**
  String get exchangeSettingsErrorLoadingAccount;

  /// exchange_settings user-facing failure message (#1895).
  ///
  /// In en, this message translates to:
  /// **'Your trading statistics could not be loaded. Please try again.'**
  String get exchangeSettingsErrorLoadingStatistics;

  /// exchange_settings user-facing failure message when the secure file upload status cannot be loaded
  ///
  /// In en, this message translates to:
  /// **'Your upload status could not be loaded. Please try again.'**
  String get exchangeSettingsErrorLoadingUploadStatus;

  /// exchange_settings user-facing failure message (#1895).
  ///
  /// In en, this message translates to:
  /// **'The document could not be uploaded. Please try again.'**
  String get exchangeSettingsErrorUploadingDocument;

  /// Title for the log in option in exchange settings
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get exchangeSettingsLogInTitle;

  /// Title for the recipients button in exchange settings
  ///
  /// In en, this message translates to:
  /// **'Recipients'**
  String get exchangeSettingsRecipientsTitle;

  /// Title for the referrals section in exchange settings
  ///
  /// In en, this message translates to:
  /// **'Referrals'**
  String get exchangeSettingsReferralsTitle;

  /// Title for the security settings section in exchange settings
  ///
  /// In en, this message translates to:
  /// **'Security Settings'**
  String get exchangeSettingsSecuritySettingsTitle;

  /// Title for the transactions button in exchange settings
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get exchangeSettingsTransactionsTitle;

  /// Label showing when statistics were last updated
  ///
  /// In en, this message translates to:
  /// **'As of {date}'**
  String exchangeStatisticsAsOf(String date);

  /// Label for average price statistic
  ///
  /// In en, this message translates to:
  /// **'Average Price'**
  String get exchangeStatisticsAveragePrice;

  /// Title for biller statistics section
  ///
  /// In en, this message translates to:
  /// **'Biller Statistics'**
  String get exchangeStatisticsBillerStats;

  /// Description for buy average price statistic
  ///
  /// In en, this message translates to:
  /// **'Average price paid per bitcoin when buying'**
  String get exchangeStatisticsBuyAvgPriceDesc;

  /// Label for buy/sell ratio statistic
  ///
  /// In en, this message translates to:
  /// **'Buy/Sell Ratio'**
  String get exchangeStatisticsBuySellRatio;

  /// Description for buy/sell ratio statistic
  ///
  /// In en, this message translates to:
  /// **'Percentage of total volume from buying vs selling'**
  String get exchangeStatisticsBuySellRatioDesc;

  /// Title for buy statistics section
  ///
  /// In en, this message translates to:
  /// **'Buy Statistics'**
  String get exchangeStatisticsBuyStats;

  /// Description for buy trade count statistic
  ///
  /// In en, this message translates to:
  /// **'Number of bitcoin purchase transactions'**
  String get exchangeStatisticsBuyTradeCountDesc;

  /// Description for buy volume statistic
  ///
  /// In en, this message translates to:
  /// **'Total amount spent buying bitcoin'**
  String get exchangeStatisticsBuyVolumeDesc;

  /// Label showing currency for biller stats
  ///
  /// In en, this message translates to:
  /// **'Currency: {currency}'**
  String exchangeStatisticsCurrency(String currency);

  /// Message when no statistics are available
  ///
  /// In en, this message translates to:
  /// **'No statistics available'**
  String get exchangeStatisticsNoData;

  /// Title for order statistics section
  ///
  /// In en, this message translates to:
  /// **'Order Statistics'**
  String get exchangeStatisticsOrderStats;

  /// Description for sell average price statistic
  ///
  /// In en, this message translates to:
  /// **'Average price received per bitcoin when selling'**
  String get exchangeStatisticsSellAvgPriceDesc;

  /// Title for sell statistics section
  ///
  /// In en, this message translates to:
  /// **'Sell Statistics'**
  String get exchangeStatisticsSellStats;

  /// Description for sell trade count statistic
  ///
  /// In en, this message translates to:
  /// **'Number of bitcoin sell transactions'**
  String get exchangeStatisticsSellTradeCountDesc;

  /// Description for sell volume statistic
  ///
  /// In en, this message translates to:
  /// **'Total amount received from selling bitcoin'**
  String get exchangeStatisticsSellVolumeDesc;

  /// Title for the statistics screen
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get exchangeStatisticsTitle;

  /// Label for total amount statistic
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get exchangeStatisticsTotalAmount;

  /// Label for total trading volume statistic
  ///
  /// In en, this message translates to:
  /// **'Total Trading Volume'**
  String get exchangeStatisticsTotalVolume;

  /// Description for total trading volume statistic
  ///
  /// In en, this message translates to:
  /// **'Combined buy and sell volumes in fiat currencies'**
  String get exchangeStatisticsTotalVolumeDesc;

  /// Label for trade count statistic
  ///
  /// In en, this message translates to:
  /// **'Trade Count'**
  String get exchangeStatisticsTradeCount;

  /// Number of trades in one fiat currency on the exchange statistics screen
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 trade ({currency})} other{{count} trades ({currency})}}'**
  String exchangeStatisticsTradeCountByCurrency(int count, String currency);

  /// Number of trades on the exchange statistics screen when there are no trades per currency
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 trade} other{{count} trades}}'**
  String exchangeStatisticsTradeCountValue(int count);

  /// Label for volume statistic
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get exchangeStatisticsVolume;

  /// Accessible tooltip for the support chat file attachment button.
  ///
  /// In en, this message translates to:
  /// **'Attach a file'**
  String get exchangeSupportChatAttachFileTooltip;

  /// Snackbar shown when attaching log files to a support chat message fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to attach logs. Please try again.'**
  String get exchangeSupportChatAttachLogsFailed;

  /// Accessible tooltip for the support chat log attachment button.
  ///
  /// In en, this message translates to:
  /// **'Attach logs'**
  String get exchangeSupportChatAttachLogsTooltip;

  /// Fallback display name for an image attachment in the support chat when no file name is available.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get exchangeSupportChatAttachmentImage;

  /// Fallback display name for a non-image attachment in the support chat when no file name is available.
  ///
  /// In en, this message translates to:
  /// **'Unknown file'**
  String get exchangeSupportChatAttachmentUnknownFile;

  /// Message shown when there are no chat messages
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Start a conversation!'**
  String get exchangeSupportChatEmptyState;

  /// Snackbar shown when downloading a support chat attachment fails because no file data was returned.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch file data'**
  String get exchangeSupportChatFetchFileDataFailed;

  /// Placeholder text for the message input field
  ///
  /// In en, this message translates to:
  /// **'Type a message…'**
  String get exchangeSupportChatInputHint;

  /// Shown when downloading or opening a support chat attachment fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the attachment. Please try again.'**
  String get exchangeSupportChatLoadAttachmentError;

  /// Shown when loading the support chat message history fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load messages. Please try again.'**
  String get exchangeSupportChatLoadMessagesError;

  /// Error message when trying to send an empty message
  ///
  /// In en, this message translates to:
  /// **'Message cannot be empty'**
  String get exchangeSupportChatMessageEmptyError;

  /// Placeholder text when attachments are present but no message text
  ///
  /// In en, this message translates to:
  /// **'A message is required'**
  String get exchangeSupportChatMessageRequired;

  /// Snackbar shown when picking files for a support chat attachment fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to pick files. Please try again.'**
  String get exchangeSupportChatPickFilesFailed;

  /// Shown when sending a support chat message fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send your message. Please try again.'**
  String get exchangeSupportChatSendMessageError;

  /// Accessible tooltip for the support chat send button.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get exchangeSupportChatSendTooltip;

  /// Title for the support chat screen
  ///
  /// In en, this message translates to:
  /// **'Support Chat'**
  String get exchangeSupportChatTitle;

  /// Label for yesterday in date formatting
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get exchangeSupportChatYesterday;

  /// Message on chat preview overlay prompting login to access support chat
  ///
  /// In en, this message translates to:
  /// **'To get human support, you must first log in to your Bull Bitcoin account. It\'s 100% free and no KYC is required, only an email address.'**
  String get exchangeSupportLoginChatRequired;

  /// Button to navigate to login screen
  ///
  /// In en, this message translates to:
  /// **'LOGIN'**
  String get loginButton;

  /// Title for not logged in state
  ///
  /// In en, this message translates to:
  /// **'You Are Not Logged in'**
  String get notLoggedInTitle;

  /// Error title when something goes wrong
  ///
  /// In en, this message translates to:
  /// **'Oops! Something went wrong'**
  String get oopsSomethingWentWrong;

  /// Generic retry button label
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Title for the app settings section in the settings menu
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get settingsAppSettingsTitle;

  /// Editable support chat draft after attaching diagnostic logs.
  ///
  /// In en, this message translates to:
  /// **'Here are my logs'**
  String get exchangeSupportChatLogDraft;
}

class _ExchangeLocalizationsDelegate
    extends LocalizationsDelegate<ExchangeLocalizations> {
  const _ExchangeLocalizationsDelegate();

  @override
  Future<ExchangeLocalizations> load(Locale locale) {
    return SynchronousFuture<ExchangeLocalizations>(
      lookupExchangeLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'as',
    'bg',
    'bn',
    'cs',
    'de',
    'el',
    'en',
    'es',
    'fa',
    'fi',
    'fr',
    'hi',
    'hy',
    'it',
    'ka',
    'ko',
    'pt',
    'ru',
    'sw',
    'th',
    'tr',
    'uk',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_ExchangeLocalizationsDelegate old) => false;
}

ExchangeLocalizations lookupExchangeLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'hi':
      {
        switch (locale.scriptCode) {
          case 'Latn':
            return ExchangeLocalizationsHiLatn();
        }
        break;
      }
  }

  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'pt':
      {
        switch (locale.countryCode) {
          case 'BR':
            return ExchangeLocalizationsPtBr();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return ExchangeLocalizationsAr();
    case 'as':
      return ExchangeLocalizationsAs();
    case 'bg':
      return ExchangeLocalizationsBg();
    case 'bn':
      return ExchangeLocalizationsBn();
    case 'cs':
      return ExchangeLocalizationsCs();
    case 'de':
      return ExchangeLocalizationsDe();
    case 'el':
      return ExchangeLocalizationsEl();
    case 'en':
      return ExchangeLocalizationsEn();
    case 'es':
      return ExchangeLocalizationsEs();
    case 'fa':
      return ExchangeLocalizationsFa();
    case 'fi':
      return ExchangeLocalizationsFi();
    case 'fr':
      return ExchangeLocalizationsFr();
    case 'hi':
      return ExchangeLocalizationsHi();
    case 'hy':
      return ExchangeLocalizationsHy();
    case 'it':
      return ExchangeLocalizationsIt();
    case 'ka':
      return ExchangeLocalizationsKa();
    case 'ko':
      return ExchangeLocalizationsKo();
    case 'pt':
      return ExchangeLocalizationsPt();
    case 'ru':
      return ExchangeLocalizationsRu();
    case 'sw':
      return ExchangeLocalizationsSw();
    case 'th':
      return ExchangeLocalizationsTh();
    case 'tr':
      return ExchangeLocalizationsTr();
    case 'uk':
      return ExchangeLocalizationsUk();
    case 'vi':
      return ExchangeLocalizationsVi();
    case 'zh':
      return ExchangeLocalizationsZh();
  }

  throw FlutterError(
    'ExchangeLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
