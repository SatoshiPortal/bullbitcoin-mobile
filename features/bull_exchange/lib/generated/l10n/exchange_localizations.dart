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

  /// Title for the account settings screen (shown to non-superusers)
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get settingsAccountSettingsTitle;

  /// settings user-facing failure message (#1895).
  ///
  /// In en, this message translates to:
  /// **'That setting could not be saved. Please try again.'**
  String get settingsErrorSavingSetting;

  /// Optional exchange access or wallet quick action setting.
  ///
  /// In en, this message translates to:
  /// **'BULL Exchange'**
  String get exchangeAccessSettingsTitle;

  /// Optional exchange access or wallet quick action setting.
  ///
  /// In en, this message translates to:
  /// **'Exchange features'**
  String get exchangeAccessSettingsLabel;

  /// Optional exchange access or wallet quick action setting.
  ///
  /// In en, this message translates to:
  /// **'Enable to sign in or create a Bull Bitcoin account.'**
  String get exchangeAccessSettingsOffHint;

  /// Optional exchange access or wallet quick action setting.
  ///
  /// In en, this message translates to:
  /// **'Exchange features are enabled.'**
  String get exchangeAccessSettingsOnHint;

  /// Optional exchange access or wallet quick action setting.
  ///
  /// In en, this message translates to:
  /// **'Sign in or create an account'**
  String get exchangeAccessSignIn;

  /// Optional exchange access or wallet quick action setting.
  ///
  /// In en, this message translates to:
  /// **'Disable exchange features?'**
  String get exchangeAccessDisableTitle;

  /// Optional exchange access or wallet quick action setting.
  ///
  /// In en, this message translates to:
  /// **'This signs you out on this device. Existing orders, AutoBuy and recurring buys are not cancelled.'**
  String get exchangeAccessDisableBody;

  /// Optional exchange access or wallet quick action setting.
  ///
  /// In en, this message translates to:
  /// **'Sign out and disable'**
  String get exchangeAccessDisableConfirm;

  /// Exchange access recovery and navigation
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get exchangeTradingRetry;

  /// Exchange access recovery and navigation
  ///
  /// In en, this message translates to:
  /// **'Exchange access could not be read. Retry or reset it.'**
  String get exchangeAccessUnreadable;

  /// Exchange access recovery and navigation
  ///
  /// In en, this message translates to:
  /// **'Reset exchange access'**
  String get exchangeAccessReset;

  /// Exchange access recovery and navigation
  ///
  /// In en, this message translates to:
  /// **'Sign out is incomplete. Finish signing out before enabling exchange.'**
  String get exchangeAccessLogoutIncomplete;

  /// Exchange access recovery and navigation
  ///
  /// In en, this message translates to:
  /// **'Finish signing out'**
  String get exchangeAccessRetryLogout;

  /// AppBar title for funding screen
  ///
  /// In en, this message translates to:
  /// **'Funding'**
  String get fundExchangeTitle;

  /// Main title on the fund exchange account screen
  ///
  /// In en, this message translates to:
  /// **'Fund your account'**
  String get fundExchangeAccountTitle;

  /// Subtitle on fund exchange account screen prompting user to select country and payment method
  ///
  /// In en, this message translates to:
  /// **'Select your country and payment method'**
  String get fundExchangeAccountSubtitle;

  /// Title shown when a restricted or prohibited user is blocked from funding
  ///
  /// In en, this message translates to:
  /// **'Funding unavailable'**
  String get fundExchangeRestrictedTitle;

  /// Message shown when a restricted or prohibited user is blocked from funding
  ///
  /// In en, this message translates to:
  /// **'Funding is not available on your account. Please contact support for more information.'**
  String get fundExchangeRestrictedMessage;

  /// Title of the scammer warning screen
  ///
  /// In en, this message translates to:
  /// **'Watch out for scammers'**
  String get fundExchangeWarningTitle;

  /// Warning message about potential scammers when funding account
  ///
  /// In en, this message translates to:
  /// **'If someone is asking you to buy Bitcoin or \"helping you\", be careful, they may be trying to scam you!'**
  String get fundExchangeWarningDescription;

  /// Title for the list of common scammer tactics
  ///
  /// In en, this message translates to:
  /// **'Common scammer tactics'**
  String get fundExchangeWarningTacticsTitle;

  /// First scammer tactic warning
  ///
  /// In en, this message translates to:
  /// **'They are promising returns on investment'**
  String get fundExchangeWarningTactic1;

  /// Second scammer tactic warning
  ///
  /// In en, this message translates to:
  /// **'They are offering you a loan'**
  String get fundExchangeWarningTactic2;

  /// Third scammer tactic warning
  ///
  /// In en, this message translates to:
  /// **'They say they work for debt or tax collection'**
  String get fundExchangeWarningTactic3;

  /// Fourth scammer tactic warning
  ///
  /// In en, this message translates to:
  /// **'They ask to send Bitcoin to their address'**
  String get fundExchangeWarningTactic4;

  /// Fifth scammer tactic warning
  ///
  /// In en, this message translates to:
  /// **'They ask to send Bitcoin on another platform'**
  String get fundExchangeWarningTactic5;

  /// Sixth scammer tactic warning
  ///
  /// In en, this message translates to:
  /// **'They want you to share your screen'**
  String get fundExchangeWarningTactic6;

  /// Seventh scammer tactic warning
  ///
  /// In en, this message translates to:
  /// **'They tell you not to worry about this warning'**
  String get fundExchangeWarningTactic7;

  /// Eighth scammer tactic warning
  ///
  /// In en, this message translates to:
  /// **'They are pressuring you to act quickly'**
  String get fundExchangeWarningTactic8;

  /// Confirmation checkbox text that user is not being coerced to buy Bitcoin
  ///
  /// In en, this message translates to:
  /// **'I confirm that I am not being asked to buy Bitcoin by someone else.'**
  String get fundExchangeWarningConfirmation;

  /// Button label to continue from warning screen to payment method details
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get fundExchangeContinueButton;

  /// Error message shown when the scam warning consent API call fails
  ///
  /// In en, this message translates to:
  /// **'Failed to register your consent. Please try again.'**
  String get fundExchangeScamConsentError;

  /// Button label to finish and exit the funding flow
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get fundExchangeDoneButton;

  /// Dropdown option for Canada jurisdiction
  ///
  /// In en, this message translates to:
  /// **'🇨🇦 Canada'**
  String get fundExchangeJurisdictionCanada;

  /// Dropdown option for Europe SEPA jurisdiction
  ///
  /// In en, this message translates to:
  /// **'🇪🇺 Europe (SEPA)'**
  String get fundExchangeJurisdictionEurope;

  /// Dropdown option for Mexico jurisdiction
  ///
  /// In en, this message translates to:
  /// **'🇲🇽 Mexico'**
  String get fundExchangeJurisdictionMexico;

  /// Dropdown option for Costa Rica jurisdiction
  ///
  /// In en, this message translates to:
  /// **'🇨🇷 Costa Rica'**
  String get fundExchangeJurisdictionCostaRica;

  /// Dropdown option for Argentina jurisdiction
  ///
  /// In en, this message translates to:
  /// **'🇦🇷 Argentina'**
  String get fundExchangeJurisdictionArgentina;

  /// Dropdown option for Colombia jurisdiction
  ///
  /// In en, this message translates to:
  /// **'🇨🇴 Colombia'**
  String get fundExchangeJurisdictionColombia;

  /// Payment method: Email E-Transfer (Canada)
  ///
  /// In en, this message translates to:
  /// **'Email E-Transfer'**
  String get fundExchangeMethodEmailETransfer;

  /// Subtitle for Email E-Transfer payment method
  ///
  /// In en, this message translates to:
  /// **'Easiest and fastest method (instant)'**
  String get fundExchangeMethodEmailETransferSubtitle;

  /// Payment method: Bank Transfer Wire or EFT (Canada)
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer (Wire or EFT)'**
  String get fundExchangeMethodBankTransferWire;

  /// Subtitle for Bank Transfer Wire payment method
  ///
  /// In en, this message translates to:
  /// **'Best and most reliable option for larger amounts (same or next day)'**
  String get fundExchangeMethodBankTransferWireSubtitle;

  /// Payment method: Online Bill Payment (Canada)
  ///
  /// In en, this message translates to:
  /// **'Online Bill Payment'**
  String get fundExchangeMethodOnlineBillPayment;

  /// Subtitle for Online Bill Payment method
  ///
  /// In en, this message translates to:
  /// **'Slowest option, but can be done via online banking (3-4 business days)'**
  String get fundExchangeMethodOnlineBillPaymentSubtitle;

  /// Payment method: In-person at Canada Post
  ///
  /// In en, this message translates to:
  /// **'In-person cash or debit at Canada Post'**
  String get fundExchangeMethodCanadaPost;

  /// Subtitle for Canada Post payment method
  ///
  /// In en, this message translates to:
  /// **'Best for those who prefer to pay in person'**
  String get fundExchangeMethodCanadaPostSubtitle;

  /// Payment method: Instant & Regular SEPA (Europe)
  ///
  /// In en, this message translates to:
  /// **'Instant & Regular SEPA'**
  String get fundExchangeMethodInstantSepa;

  /// Subtitle for Instant SEPA payment method
  ///
  /// In en, this message translates to:
  /// **'Fastest - Only for transactions below €30,000'**
  String get fundExchangeMethodInstantSepaSubtitle;

  /// Payment method: Regular SEPA (Europe)
  ///
  /// In en, this message translates to:
  /// **'Regular SEPA'**
  String get fundExchangeMethodRegularSepa;

  /// Subtitle for Regular SEPA payment method
  ///
  /// In en, this message translates to:
  /// **'Only use for larger transactions above €30,000'**
  String get fundExchangeMethodRegularSepaSubtitle;

  /// Screen title for bank transfer wire payment details
  ///
  /// In en, this message translates to:
  /// **'Bank transfer (wire)'**
  String get fundExchangeBankTransferWireTitle;

  /// Description of how to use bank transfer wire method
  ///
  /// In en, this message translates to:
  /// **'Send a wire transfer from your bank account using Bull Bitcoin\'s bank details below. Your bank may require only some parts of these details.'**
  String get fundExchangeBankTransferWireDescription;

  /// Timeframe for bank transfer wire funds to be credited
  ///
  /// In en, this message translates to:
  /// **'Any funds you send will be added to your Bull Bitcoin within 1-2 business days.'**
  String get fundExchangeBankTransferWireTimeframe;

  /// Label for beneficiary name field
  ///
  /// In en, this message translates to:
  /// **'Beneficiary name'**
  String get fundExchangeLabelBeneficiaryName;

  /// Help text for beneficiary name field
  ///
  /// In en, this message translates to:
  /// **'Use our official corporate name. Do not use \"Bull Bitcoin\".'**
  String get fundExchangeHelpBeneficiaryName;

  /// Label for transfer code field
  ///
  /// In en, this message translates to:
  /// **'Transfer code (add this as payment description)'**
  String get fundExchangeLabelTransferCode;

  /// Help text for transfer code field
  ///
  /// In en, this message translates to:
  /// **'Add this as the reason for the transfer'**
  String get fundExchangeHelpTransferCode;

  /// Info card message about transfer code importance
  ///
  /// In en, this message translates to:
  /// **'You must add the transfer code as the \"message\" or \"reason\" when making the payment.'**
  String get fundExchangeInfoTransferCode;

  /// Label for bank account details field
  ///
  /// In en, this message translates to:
  /// **'Bank account details'**
  String get fundExchangeLabelBankAccountDetails;

  /// Label for SWIFT code field
  ///
  /// In en, this message translates to:
  /// **'SWIFT code'**
  String get fundExchangeLabelSwiftCode;

  /// Label for institution number field
  ///
  /// In en, this message translates to:
  /// **'Institution number'**
  String get fundExchangeLabelInstitutionNumber;

  /// Label for transit number field
  ///
  /// In en, this message translates to:
  /// **'Transit number'**
  String get fundExchangeLabelTransitNumber;

  /// Label for routing number field
  ///
  /// In en, this message translates to:
  /// **'Routing number'**
  String get fundExchangeLabelRoutingNumber;

  /// Label for beneficiary address field
  ///
  /// In en, this message translates to:
  /// **'Beneficiary address'**
  String get fundExchangeLabelBeneficiaryAddress;

  /// Label for bank name field
  ///
  /// In en, this message translates to:
  /// **'Bank name'**
  String get fundExchangeLabelBankName;

  /// Label for bank address field
  ///
  /// In en, this message translates to:
  /// **'Address of our bank'**
  String get fundExchangeLabelBankAddress;

  /// Screen title for E-Transfer payment details
  ///
  /// In en, this message translates to:
  /// **'E-Transfer details'**
  String get fundExchangeETransferTitle;

  /// Description of how E-Transfer works and timeframe
  ///
  /// In en, this message translates to:
  /// **'Any amount you send from your bank via Email E-Transfer using the information below will be credited to your Bull Bitcoin account balance within a few minutes.'**
  String get fundExchangeETransferDescription;

  /// Label for E-transfer beneficiary name
  ///
  /// In en, this message translates to:
  /// **'Use this as the E-transfer beneficiary name'**
  String get fundExchangeETransferLabelBeneficiaryName;

  /// Label for E-transfer recipient email
  ///
  /// In en, this message translates to:
  /// **'Send the E-transfer to this email'**
  String get fundExchangeETransferLabelEmail;

  /// Label for E-transfer security question
  ///
  /// In en, this message translates to:
  /// **'Secret question'**
  String get fundExchangeETransferLabelSecretQuestion;

  /// Label for E-transfer security answer
  ///
  /// In en, this message translates to:
  /// **'Secret answer'**
  String get fundExchangeETransferLabelSecretAnswer;

  /// Screen title for Online Bill Payment details
  ///
  /// In en, this message translates to:
  /// **'Online Bill Payment'**
  String get fundExchangeOnlineBillPaymentTitle;

  /// Description of how online bill payment works and timeframe
  ///
  /// In en, this message translates to:
  /// **'Any amount you send via your bank\'s online bill payment feature using the information below will be credited to your Bull Bitcoin account balance within 3-4 business days.'**
  String get fundExchangeOnlineBillPaymentDescription;

  /// Label for biller name in online bill payment
  ///
  /// In en, this message translates to:
  /// **'Search your bank\'s list of billers for this name'**
  String get fundExchangeOnlineBillPaymentLabelBillerName;

  /// Help text for biller name field
  ///
  /// In en, this message translates to:
  /// **'Add this company as a payee - it\'s Bull Bitcoin\'s payment processor'**
  String get fundExchangeOnlineBillPaymentHelpBillerName;

  /// Screen title for Canada Post payment method
  ///
  /// In en, this message translates to:
  /// **'In-person cash or debit at Canada Post'**
  String get fundExchangeCanadaPostTitle;

  /// Step 1 for Canada Post payment process
  ///
  /// In en, this message translates to:
  /// **'1. Go to any Canada Post location'**
  String get fundExchangeCanadaPostStep1;

  /// Step 2 for Canada Post payment process
  ///
  /// In en, this message translates to:
  /// **'2. Ask the cashier to scan the \"Loadhub\" QR code'**
  String get fundExchangeCanadaPostStep2;

  /// Step 3 for Canada Post payment process
  ///
  /// In en, this message translates to:
  /// **'3. Tell the cashier the amount you want to load'**
  String get fundExchangeCanadaPostStep3;

  /// Step 4 for Canada Post payment process - ID verification
  ///
  /// In en, this message translates to:
  /// **'4. The cashier will ask to see a piece of government-issued ID and verify that the name on your ID matches your Bull Bitcoin account'**
  String get fundExchangeCanadaPostStep4;

  /// Step 5 for Canada Post payment process
  ///
  /// In en, this message translates to:
  /// **'5. Pay with cash or debit card'**
  String get fundExchangeCanadaPostStep5;

  /// Step 6 for Canada Post payment process
  ///
  /// In en, this message translates to:
  /// **'6. The cashier will hand you a receipt, keep it as your proof of payment'**
  String get fundExchangeCanadaPostStep6;

  /// Step 7 for Canada Post payment process - timeframe
  ///
  /// In en, this message translates to:
  /// **'7. The funds will be added to your Bull Bitcoin account balance within 30 minutes'**
  String get fundExchangeCanadaPostStep7;

  /// Label for the Loadhub QR code display
  ///
  /// In en, this message translates to:
  /// **'Loadhub QR code'**
  String get fundExchangeCanadaPostQrCodeLabel;

  /// Screen title for SEPA transfer payment details
  ///
  /// In en, this message translates to:
  /// **'SEPA transfer'**
  String get fundExchangeSepaTitle;

  /// Description for SEPA transfer (first part, before 'exactly')
  ///
  /// In en, this message translates to:
  /// **'Send a SEPA transfer from your bank account using the details below '**
  String get fundExchangeSepaDescription;

  /// Emphasized word 'exactly' in SEPA description
  ///
  /// In en, this message translates to:
  /// **'exactly.'**
  String get fundExchangeSepaDescriptionExactly;

  /// Info message for Instant SEPA transaction limits
  ///
  /// In en, this message translates to:
  /// **'Only use for transactions below €20,000. For larger transactions, use the Regular SEPA option.'**
  String get fundExchangeInstantSepaInfo;

  /// Info message for Regular SEPA transaction limits
  ///
  /// In en, this message translates to:
  /// **'Only use for transactions above €20,000. For smaller transactions, use the Instant SEPA option.'**
  String get fundExchangeRegularSepaInfo;

  /// Label for IBAN account number field
  ///
  /// In en, this message translates to:
  /// **'IBAN account number'**
  String get fundExchangeLabelIban;

  /// Label for BIC code field
  ///
  /// In en, this message translates to:
  /// **'BIC code'**
  String get fundExchangeLabelBicCode;

  /// Label for bank account country field
  ///
  /// In en, this message translates to:
  /// **'Bank account country'**
  String get fundExchangeLabelBankAccountCountry;

  /// Info message that bank country is United Kingdom
  ///
  /// In en, this message translates to:
  /// **'Our bank country is the United Kingdom.'**
  String get fundExchangeInfoBankCountryUk;

  /// Critical info about beneficiary name being LEONOD
  ///
  /// In en, this message translates to:
  /// **'The name of the beneficiary should be LEONOD. If you put anything else, your payment will be rejected.'**
  String get fundExchangeInfoBeneficiaryNameLeonod;

  /// Info about adding transfer code to payment description
  ///
  /// In en, this message translates to:
  /// **'In the payment description, add your transfer code.'**
  String get fundExchangeInfoPaymentDescription;

  /// Help text for beneficiary address field
  ///
  /// In en, this message translates to:
  /// **'Our official address, in case this is required by your bank'**
  String get fundExchangeHelpBeneficiaryAddress;

  /// Label for recipient name field (alternative to beneficiary name)
  ///
  /// In en, this message translates to:
  /// **'Recipient name'**
  String get fundExchangeLabelRecipientName;

  /// Label for bank country field
  ///
  /// In en, this message translates to:
  /// **'Bank country'**
  String get fundExchangeLabelBankCountry;

  /// Label for recipient address field
  ///
  /// In en, this message translates to:
  /// **'Recipient address'**
  String get fundExchangeLabelRecipientAddress;

  /// Screen title for SPEI transfer (Mexico)
  ///
  /// In en, this message translates to:
  /// **'SPEI transfer'**
  String get fundExchangeSpeiTitle;

  /// Description for SPEI transfer method
  ///
  /// In en, this message translates to:
  /// **'Transfer funds using your CLABE'**
  String get fundExchangeSpeiDescription;

  /// Info message about SPEI transfer being instant
  ///
  /// In en, this message translates to:
  /// **'Make a deposit using SPEI transfer (instant).'**
  String get fundExchangeSpeiInfo;

  /// Label for CLABE number field (Mexico)
  ///
  /// In en, this message translates to:
  /// **'CLABE'**
  String get fundExchangeLabelClabe;

  /// Label for memo/reference field
  ///
  /// In en, this message translates to:
  /// **'Memo'**
  String get fundExchangeLabelMemo;

  /// Screen title for SINPE transfer (Costa Rica)
  ///
  /// In en, this message translates to:
  /// **'SINPE Transfer'**
  String get fundExchangeSinpeTitle;

  /// Description for SINPE transfer method
  ///
  /// In en, this message translates to:
  /// **'Transfer Colones using SINPE'**
  String get fundExchangeSinpeDescription;

  /// Screen title for Costa Rica bank transfer in Colones
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer (CRC)'**
  String get fundExchangeCrIbanCrcTitle;

  /// Screen title for Costa Rica bank transfer in US Dollars
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer (USD)'**
  String get fundExchangeCrIbanUsdTitle;

  /// Screen title for Argentina bank transfer
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get fundExchangeArsBankTransferTitle;

  /// Description for Argentina bank transfer method
  ///
  /// In en, this message translates to:
  /// **'Send a bank transfer from your bank account using the exact Argentina bank details below.'**
  String get fundExchangeArsBankTransferDescription;

  /// Label for recipient name in Argentina transfer
  ///
  /// In en, this message translates to:
  /// **'Recipient Name'**
  String get fundExchangeLabelRecipientNameArs;

  /// Label for CVU (Clave Virtual Uniforme) number in Argentina
  ///
  /// In en, this message translates to:
  /// **'CVU'**
  String get fundExchangeLabelCvu;

  /// Error message when funding details fail to load
  ///
  /// In en, this message translates to:
  /// **'The payment details could not be loaded at this moment. Please go back and try again, pick another payment method or come back later.'**
  String get fundExchangeErrorLoadingDetails;

  /// bb-exchange errorTitleOrdPo404
  ///
  /// In en, this message translates to:
  /// **'Payment Option Unavailable'**
  String get fundExchangeErrorTitleOrdPo404;

  /// bb-exchange errorMsgOrdPo404
  ///
  /// In en, this message translates to:
  /// **'No payment option available'**
  String get fundExchangeErrorOrdPo404;

  /// bb-exchange errorTitleRcpPo404
  ///
  /// In en, this message translates to:
  /// **'Payment Option Not Available'**
  String get fundExchangeErrorTitleRcpPo404;

  /// bb-exchange errorMsgRcpPo404
  ///
  /// In en, this message translates to:
  /// **'You do not have the required permissions to access this funding option. Either your KYC is insufficient or this option is not available for your account'**
  String get fundExchangeErrorRcpPo404;

  /// bb-exchange errorTitleRcpPosinpe404
  ///
  /// In en, this message translates to:
  /// **'SINPE Not Available'**
  String get fundExchangeErrorTitleRcpPosinpe404;

  /// bb-exchange errorMsgRcpPosinpe404
  ///
  /// In en, this message translates to:
  /// **'To access this funding option, your phone number must be registered with the SINPE network in Costa Rica.'**
  String get fundExchangeErrorRcpPosinpe404;

  /// bb-exchange errorTitleOrdKyc400
  ///
  /// In en, this message translates to:
  /// **'KYC Requirements Missing'**
  String get fundExchangeErrorTitleOrdKyc400;

  /// bb-exchange errorMsgOrdKyc400. The API names the missing fields in messageData.missingFields; that is backend-controlled text, kept to logs only (#1895).
  ///
  /// In en, this message translates to:
  /// **'You do not have the KYC requirements for this action'**
  String get fundExchangeErrorOrdKyc400;

  /// bb-exchange errorTitleOrdCop400
  ///
  /// In en, this message translates to:
  /// **'Invalid COP Funding Data'**
  String get fundExchangeErrorTitleOrdCop400;

  /// bb-exchange errorMsgOrdCop400. The API's raw error sentence is kept to logs only (#1895).
  ///
  /// In en, this message translates to:
  /// **'Invalid request data for COP funding'**
  String get fundExchangeErrorOrdCop400;

  /// bb-exchange: shown when the COP payment link cannot be handed to a browser (#1895).
  ///
  /// In en, this message translates to:
  /// **'The payment link could not be opened. Please try again.'**
  String get fundExchangeErrorOpeningPaymentLink;

  /// bb-exchange errorTitleOrdCsrcp400
  ///
  /// In en, this message translates to:
  /// **'Virtual Payment Not Activated'**
  String get fundExchangeErrorTitleOrdCsrcp400;

  /// bb-exchange errorMsgOrdCsrcp400. The API returns the recipient IBAN in messageData.iban; it is backend-controlled text, kept to logs only (#1895). Copy deliberately omits the IBAN, so it carries no placeholder.
  ///
  /// In en, this message translates to:
  /// **'Please activate the virtual payment option for this SEPA recipient'**
  String get fundExchangeErrorOrdCsrcp400;

  /// bb-exchange errorTitleRcp400
  ///
  /// In en, this message translates to:
  /// **'Invalid Request'**
  String get fundExchangeErrorTitleRcp400;

  /// bb-exchange errorMsgRcp400
  ///
  /// In en, this message translates to:
  /// **'Invalid request'**
  String get fundExchangeErrorRcp400;

  /// bb-exchange FundingCubit._loadBankCodesCopBitso empty-list error
  ///
  /// In en, this message translates to:
  /// **'Error fetching bank codes. Please try again later.'**
  String get fundExchangeErrorFetchingBankCodes;

  /// Bold text warning that payment from wrong number will be rejected
  ///
  /// In en, this message translates to:
  /// **'it will be rejected.'**
  String get fundExchangeSinpeDescriptionBold;

  /// Message explaining that payment will be added to account balance
  ///
  /// In en, this message translates to:
  /// **'Once the payment is sent, it will be added to your account balance.'**
  String get fundExchangeSinpeAddedToBalance;

  /// Label for SINPE Móvil phone number field
  ///
  /// In en, this message translates to:
  /// **'Send to this phone number'**
  String get fundExchangeSinpeLabelPhone;

  /// Label for recipient name in SINPE transfer
  ///
  /// In en, this message translates to:
  /// **'Recipient Name'**
  String get fundExchangeSinpeLabelRecipientName;

  /// First part of description for CR IBAN CRC transfer
  ///
  /// In en, this message translates to:
  /// **'Send a bank transfer from your bank account using the details below '**
  String get fundExchangeCrIbanCrcDescription;

  /// Bold emphasis word for CR IBAN transfer instructions
  ///
  /// In en, this message translates to:
  /// **'exactly'**
  String get fundExchangeCrIbanCrcDescriptionBold;

  /// End of description for CR IBAN CRC transfer
  ///
  /// In en, this message translates to:
  /// **'. Funds will be added to your account balance.'**
  String get fundExchangeCrIbanCrcDescriptionEnd;

  /// Label for IBAN number field for CRC (Colones) only
  ///
  /// In en, this message translates to:
  /// **'IBAN Account Number (Colones only)'**
  String get fundExchangeCrIbanCrcLabelIban;

  /// Label for payment description field in CR IBAN transfer
  ///
  /// In en, this message translates to:
  /// **'Payment Description'**
  String get fundExchangeCrIbanCrcLabelPaymentDescription;

  /// Help text explaining payment description is the transfer code
  ///
  /// In en, this message translates to:
  /// **'Your transfer code.'**
  String get fundExchangeCrIbanCrcPaymentDescriptionHelp;

  /// Warning about including transfer code in payment
  ///
  /// In en, this message translates to:
  /// **'You must add the transfer code as \"message\" or \"reason\" or \"description\" when making the payment. If you forget to include this code, your payment may be rejected.'**
  String get fundExchangeCrIbanCrcTransferCodeWarning;

  /// Label for recipient name in CR IBAN CRC transfer
  ///
  /// In en, this message translates to:
  /// **'Recipient Name'**
  String get fundExchangeCrIbanCrcLabelRecipientName;

  /// Help text for recipient name field explaining to use corporate name
  ///
  /// In en, this message translates to:
  /// **'Use our official corporate name. Do not use \"Bull Bitcoin\".'**
  String get fundExchangeCrIbanCrcRecipientNameHelp;

  /// Label for Cédula Jurídica (legal ID number in Costa Rica)
  ///
  /// In en, this message translates to:
  /// **'Cédula Jurídica'**
  String get fundExchangeCrIbanCrcLabelCedulaJuridica;

  /// First part of description for CR IBAN USD transfer
  ///
  /// In en, this message translates to:
  /// **'Send a bank transfer from your bank account using the details below '**
  String get fundExchangeCrIbanUsdDescription;

  /// Bold emphasis word for CR IBAN USD transfer instructions
  ///
  /// In en, this message translates to:
  /// **'exactly'**
  String get fundExchangeCrIbanUsdDescriptionBold;

  /// End of description for CR IBAN USD transfer
  ///
  /// In en, this message translates to:
  /// **'. Funds will be added to your account balance.'**
  String get fundExchangeCrIbanUsdDescriptionEnd;

  /// Label for IBAN number field for USD only
  ///
  /// In en, this message translates to:
  /// **'IBAN Account Number (US dollars only)'**
  String get fundExchangeCrIbanUsdLabelIban;

  /// Label for payment description field in CR IBAN USD transfer
  ///
  /// In en, this message translates to:
  /// **'Payment Description'**
  String get fundExchangeCrIbanUsdLabelPaymentDescription;

  /// Help text explaining payment description is the transfer code
  ///
  /// In en, this message translates to:
  /// **'Your transfer code.'**
  String get fundExchangeCrIbanUsdPaymentDescriptionHelp;

  /// Warning about including transfer code in payment for USD transfers
  ///
  /// In en, this message translates to:
  /// **'You must add the transfer code as \"message\" or \"reason\" or \"description\" when making the payment. If you forget to include this code, your payment may be rejected.'**
  String get fundExchangeCrIbanUsdTransferCodeWarning;

  /// Label for recipient name in CR IBAN USD transfer
  ///
  /// In en, this message translates to:
  /// **'Recipient Name'**
  String get fundExchangeCrIbanUsdLabelRecipientName;

  /// Help text for recipient name field explaining to use corporate name
  ///
  /// In en, this message translates to:
  /// **'Use our official corporate name. Do not use \"Bull Bitcoin\".'**
  String get fundExchangeCrIbanUsdRecipientNameHelp;

  /// Label for Cédula Jurídica (legal ID number in Costa Rica) for USD
  ///
  /// In en, this message translates to:
  /// **'Cédula Jurídica'**
  String get fundExchangeCrIbanUsdLabelCedulaJuridica;

  /// Payment method title for SINPE Móvil in method list
  ///
  /// In en, this message translates to:
  /// **'SINPE Móvil'**
  String get fundExchangeCostaRicaMethodSinpeTitle;

  /// Subtitle description for SINPE Móvil payment method
  ///
  /// In en, this message translates to:
  /// **'Transfer Colones using SINPE'**
  String get fundExchangeCostaRicaMethodSinpeSubtitle;

  /// Payment method title for IBAN CRC in method list
  ///
  /// In en, this message translates to:
  /// **'IBAN Costa Rica (CRC)'**
  String get fundExchangeCostaRicaMethodIbanCrcTitle;

  /// Subtitle description for IBAN CRC payment method
  ///
  /// In en, this message translates to:
  /// **'Transfer funds in Costa Rican Colón (CRC)'**
  String get fundExchangeCostaRicaMethodIbanCrcSubtitle;

  /// Payment method title for IBAN USD in method list
  ///
  /// In en, this message translates to:
  /// **'IBAN Costa Rica (USD)'**
  String get fundExchangeCostaRicaMethodIbanUsdTitle;

  /// Subtitle description for IBAN USD payment method
  ///
  /// In en, this message translates to:
  /// **'Transfer funds in US Dollars (USD)'**
  String get fundExchangeCostaRicaMethodIbanUsdSubtitle;

  /// Button to close advanced options bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneButton;

  /// SPEI transfer method title (Mexico)
  ///
  /// In en, this message translates to:
  /// **'SPEI transfer'**
  String get fundExchangeSpeiTransfer;

  /// SPEI transfer subtitle
  ///
  /// In en, this message translates to:
  /// **'Transfer funds using your CLABE'**
  String get fundExchangeSpeiSubtitle;

  /// Bank transfer method title
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get fundExchangeBankTransfer;

  /// Bank transfer subtitle
  ///
  /// In en, this message translates to:
  /// **'Send a bank transfer from your bank account'**
  String get fundExchangeBankTransferSubtitle;

  /// Warning about daily transaction limit for COP bank transfer
  ///
  /// In en, this message translates to:
  /// **'If you exceed your daily transaction limit, the transaction will fail. You will have to contact customer support.'**
  String get fundExchangeCopDailyLimitWarning;

  /// Label for sender name field in COP bank transfer
  ///
  /// In en, this message translates to:
  /// **'Sender Name'**
  String get fundExchangeCopSenderName;

  /// Label for issuing bank dropdown in COP bank transfer
  ///
  /// In en, this message translates to:
  /// **'Issuing Bank'**
  String get fundExchangeCopIssuingBank;

  /// Validation error when no bank is selected
  ///
  /// In en, this message translates to:
  /// **'Please select an issuing bank'**
  String get fundExchangeCopSelectBankError;

  /// Label for amount field in COP bank transfer
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get fundExchangeCopAmount;

  /// Validation error when amount is empty
  ///
  /// In en, this message translates to:
  /// **'Please enter an amount'**
  String get fundExchangeCopEnterAmountError;

  /// Validation error when amount is invalid
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount'**
  String get fundExchangeCopValidAmountError;

  /// Button label to generate COP payment link
  ///
  /// In en, this message translates to:
  /// **'Generate Payment Link'**
  String get fundExchangeCopGeneratePaymentLink;

  /// Message about redirect to external payment page
  ///
  /// In en, this message translates to:
  /// **'You will be redirected to an external page to make the payment.'**
  String get fundExchangeCopRedirectMessage;

  /// Button label to open COP payment link
  ///
  /// In en, this message translates to:
  /// **'Open Payment Link'**
  String get fundExchangeCopOpenPaymentLink;

  /// Shown when a funding request could not reach the server or timed out. Same wording as recipientsErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get fundExchangeErrorNetwork;

  /// Title of the Confidential SEPA funding method
  ///
  /// In en, this message translates to:
  /// **'Confidential SEPA'**
  String get fundExchangeMethodConfidentialSepa;

  /// Subtitle of the Confidential SEPA funding method
  ///
  /// In en, this message translates to:
  /// **'A personal virtual IBAN to deposit money privately'**
  String get fundExchangeMethodConfidentialSepaSubtitle;

  /// Refusal when a service does not support the active network
  ///
  /// In en, this message translates to:
  /// **'This feature is unavailable on the selected network.'**
  String get networkFeatureUnavailable;

  /// Label for account number in online bill payment
  ///
  /// In en, this message translates to:
  /// **'Add this as the account number'**
  String get fundExchangeOnlineBillPaymentLabelAccountNumber;

  /// Help text for account number field
  ///
  /// In en, this message translates to:
  /// **'This unique account number is created just for you'**
  String get fundExchangeOnlineBillPaymentHelpAccountNumber;

  /// Bold warning text at start of bitcoin warning message
  ///
  /// In en, this message translates to:
  /// **'Do not put'**
  String get fundExchangeSinpeWarningNoBitcoin;

  /// Warning that including Bitcoin or Crypto in description will block payment
  ///
  /// In en, this message translates to:
  /// **' the word \"Bitcoin\" or \"Crypto\" in the payment description. This will block your payment.'**
  String get fundExchangeSinpeWarningNoBitcoinDescription;

  /// Title for the currency selection dropdown
  ///
  /// In en, this message translates to:
  /// **'Select Currency'**
  String get exchangeCurrencyDropdownTitle;

  /// Validation message when no currency is selected
  ///
  /// In en, this message translates to:
  /// **'Please select a currency'**
  String get exchangeCurrencyDropdownValidation;

  /// Title for the amount input field
  ///
  /// In en, this message translates to:
  /// **'Enter Amount'**
  String get exchangeAmountInputTitle;

  /// Validation message when amount field is empty
  ///
  /// In en, this message translates to:
  /// **'Please enter an amount'**
  String get exchangeAmountInputValidationEmpty;

  /// Validation message when amount is invalid
  ///
  /// In en, this message translates to:
  /// **'Invalid amount'**
  String get exchangeAmountInputValidationInvalid;

  /// Validation message when amount is zero or negative
  ///
  /// In en, this message translates to:
  /// **'Amount must be greater than zero'**
  String get exchangeAmountInputValidationZero;

  /// Validation message when amount exceeds available balance
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance'**
  String get exchangeAmountInputValidationInsufficient;

  /// Label for Bitcoin address field in exchange Bitcoin wallets
  ///
  /// In en, this message translates to:
  /// **'Bitcoin Address'**
  String get exchangeBitcoinWalletsBitcoinAddressLabel;

  /// Label for Lightning address field in exchange Bitcoin wallets
  ///
  /// In en, this message translates to:
  /// **'Lightning (LN address)'**
  String get exchangeBitcoinWalletsLightningAddressLabel;

  /// Label for Liquid address field in exchange Bitcoin wallets
  ///
  /// In en, this message translates to:
  /// **'Liquid address'**
  String get exchangeBitcoinWalletsLiquidAddressLabel;

  /// Hint text for entering an address in exchange Bitcoin wallets
  ///
  /// In en, this message translates to:
  /// **'Enter address'**
  String get exchangeBitcoinWalletsEnterAddressHint;

  /// Success message when wallet address is saved
  ///
  /// In en, this message translates to:
  /// **'Wallet address saved successfully'**
  String get exchangeBitcoinWalletsSaveSuccess;

  /// Description text on the default bitcoin wallets screen
  ///
  /// In en, this message translates to:
  /// **'Set default wallet addresses for automatic Bitcoin withdrawals.'**
  String get exchangeBitcoinWalletsDescription;

  /// Label for Bitcoin address in DCA settings
  ///
  /// In en, this message translates to:
  /// **'Bitcoin address'**
  String get exchangeDcaAddressLabelBitcoin;

  /// Label for Lightning address in DCA settings
  ///
  /// In en, this message translates to:
  /// **'Lightning address'**
  String get exchangeDcaAddressLabelLightning;

  /// Label for Liquid address in DCA settings
  ///
  /// In en, this message translates to:
  /// **'Liquid address'**
  String get exchangeDcaAddressLabelLiquid;

  /// Generic cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Generic delete button label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Generic save button label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Error shown when the default Bitcoin wallets of the exchange account cannot be loaded
  ///
  /// In en, this message translates to:
  /// **'Failed to load default wallets'**
  String get exchangeBitcoinWalletsLoadFailed;

  /// Error shown when saving an empty default wallet address
  ///
  /// In en, this message translates to:
  /// **'Address cannot be empty'**
  String get exchangeBitcoinWalletsAddressEmpty;

  /// Error shown when a default wallet address cannot be saved
  ///
  /// In en, this message translates to:
  /// **'Failed to save wallet address'**
  String get exchangeBitcoinWalletsSaveFailed;

  /// Error shown when a default wallet address cannot be deleted
  ///
  /// In en, this message translates to:
  /// **'Failed to delete wallet address'**
  String get exchangeBitcoinWalletsDeleteFailed;

  /// No description provided for @destinationExpectedType.
  ///
  /// In en, this message translates to:
  /// **'Enter or scan a valid {type}.'**
  String destinationExpectedType(String type);
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
