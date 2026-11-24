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

  /// Optional exchange access or wallet quick action setting.
  ///
  /// In en, this message translates to:
  /// **'BULL Exchange'**
  String get wizardExchangeTitle;

  /// Optional exchange access or wallet quick action setting.
  ///
  /// In en, this message translates to:
  /// **'Buy, sell and pay with Bull Bitcoin directly from your wallet.'**
  String get wizardExchangeDescription;

  /// Title for the terms of service section in the settings menu
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get settingsTermsOfServiceTitle;

  /// Default button text for success state
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// Title for the AutoBuy dashboard card and screen
  ///
  /// In en, this message translates to:
  /// **'Auto-Buy'**
  String get autoBuyTitle;

  /// Short description of AutoBuy
  ///
  /// In en, this message translates to:
  /// **'Automatically buy bitcoin each time you deposit funds into your account'**
  String get autoBuyDescription;

  /// Button label to open the AutoBuy activation flow
  ///
  /// In en, this message translates to:
  /// **'Activate Auto-Buy'**
  String get autoBuyActivate;

  /// Button label to deactivate AutoBuy
  ///
  /// In en, this message translates to:
  /// **'Deactivate Auto-Buy'**
  String get autoBuyDeactivate;

  /// Title of the AutoBuy deactivation confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Cancel Auto-Buy?'**
  String get autoBuyCancelTitle;

  /// Message in the AutoBuy deactivation confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'You will not automatically buy bitcoin next time you fund your account.'**
  String get autoBuyCancelMessage;

  /// Confirmation button for deactivating AutoBuy
  ///
  /// In en, this message translates to:
  /// **'Yes, deactivate'**
  String get autoBuyDeactivateConfirm;

  /// Heading above the AutoBuy explanation
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get autoBuyHowItWorks;

  /// First AutoBuy explanation step
  ///
  /// In en, this message translates to:
  /// **'Connect your Bitcoin, Lightning, or Liquid wallet'**
  String get autoBuyConnectWallet;

  /// Second AutoBuy explanation step
  ///
  /// In en, this message translates to:
  /// **'A Bitcoin purchase is automatically created each time you fund your Bull Bitcoin account.'**
  String get autoBuyPurchaseCreated;

  /// Third AutoBuy explanation step
  ///
  /// In en, this message translates to:
  /// **'Bitcoin is sent directly to your own wallet.'**
  String get autoBuyBitcoinSent;

  /// Risk notice shown before an AutoBuy is enabled
  ///
  /// In en, this message translates to:
  /// **'Order execution cannot be guaranteed. Delays or price changes between the deposit and purchase can change the effective rate.'**
  String get autoBuyRiskDisclaimer;

  /// Button label to start AutoBuy setup
  ///
  /// In en, this message translates to:
  /// **'Get started with Auto-Buy'**
  String get autoBuyGetStarted;

  /// Title of the AutoBuy confirmation screen
  ///
  /// In en, this message translates to:
  /// **'Confirm Auto-Buy'**
  String get autoBuyConfirmTitle;

  /// Explanation on the AutoBuy confirmation screen
  ///
  /// In en, this message translates to:
  /// **'Any amount added to your account will be converted to Bitcoin at the current exchange rate and sent to your wallet.'**
  String get autoBuyInfoMessage;

  /// Error shown when AutoBuy cannot load the exchange account
  ///
  /// In en, this message translates to:
  /// **'Your Bull Bitcoin account is not available. Try again later.'**
  String get autoBuyAccountUnavailableError;

  /// Error shown when AutoBuy is enabled without a default wallet
  ///
  /// In en, this message translates to:
  /// **'Add at least one default Bitcoin, Lightning, or Liquid address.'**
  String get autoBuyWalletRequiredError;

  /// Error shown when enabling or disabling AutoBuy fails
  ///
  /// In en, this message translates to:
  /// **'Auto-buy could not be updated. Try again later.'**
  String get autoBuyUpdateError;

  /// Title of the dialog shown when exchange login fails
  ///
  /// In en, this message translates to:
  /// **'Login Failed'**
  String get exchangeAuthLoginFailedTitle;

  /// Message shown when exchange login fails
  ///
  /// In en, this message translates to:
  /// **'An error occurred, please try logging in again.'**
  String get exchangeAuthLoginFailedMessage;

  /// OK button label in the login failed dialog
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get exchangeAuthLoginFailedOkButton;

  /// Exchange access recovery and navigation
  ///
  /// In en, this message translates to:
  /// **'Trading is unavailable.'**
  String get exchangeTradingUnavailable;

  /// The title of the settings screen
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsScreenTitle;

  /// Title for the transaction history page and settings entry
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get transactionHistoryTitle;

  /// Button label for depositing funds to the exchange
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get exchangeHomeDepositButton;

  /// Button label for withdrawing funds from the exchange
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get exchangeHomeWithdrawButton;

  /// Error message when DCA configuration cannot be retrieved
  ///
  /// In en, this message translates to:
  /// **'Unable to get DCA configuration'**
  String get exchangeDcaUnableToGetConfig;

  /// Title shown when DCA is active and can be deactivated
  ///
  /// In en, this message translates to:
  /// **'Deactivate Recurring Buy'**
  String get exchangeDcaDeactivateTitle;

  /// Title shown when DCA is inactive and can be activated
  ///
  /// In en, this message translates to:
  /// **'Activate Recurring Buy'**
  String get exchangeDcaActivateTitle;

  /// Link text to hide DCA settings details
  ///
  /// In en, this message translates to:
  /// **'Hide settings'**
  String get exchangeDcaHideSettings;

  /// Link text to view DCA settings details
  ///
  /// In en, this message translates to:
  /// **'View settings'**
  String get exchangeDcaViewSettings;

  /// Title of the dialog confirming DCA cancellation
  ///
  /// In en, this message translates to:
  /// **'Cancel Bitcoin Recurring Buy?'**
  String get exchangeDcaCancelDialogTitle;

  /// Message explaining the consequences of canceling DCA
  ///
  /// In en, this message translates to:
  /// **'Your recurring Bitcoin purchase plan will stop, and scheduled buys will end. To restart, you\'ll need to set up a new plan.'**
  String get exchangeDcaCancelDialogMessage;

  /// Button label to cancel the DCA cancellation dialog
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get exchangeDcaCancelDialogCancelButton;

  /// Button label to confirm DCA deactivation
  ///
  /// In en, this message translates to:
  /// **'Yes, deactivate'**
  String get exchangeDcaCancelDialogConfirmButton;

  /// DCA frequency unit: hour
  ///
  /// In en, this message translates to:
  /// **'hour'**
  String get exchangeDcaFrequencyHour;

  /// DCA frequency unit: day
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get exchangeDcaFrequencyDay;

  /// DCA frequency unit: week
  ///
  /// In en, this message translates to:
  /// **'week'**
  String get exchangeDcaFrequencyWeek;

  /// DCA frequency unit: month
  ///
  /// In en, this message translates to:
  /// **'month'**
  String get exchangeDcaFrequencyMonth;

  /// DCA network option: Bitcoin
  ///
  /// In en, this message translates to:
  /// **'Bitcoin Network'**
  String get exchangeDcaNetworkBitcoin;

  /// DCA network option: Lightning
  ///
  /// In en, this message translates to:
  /// **'Lightning Network'**
  String get exchangeDcaNetworkLightning;

  /// DCA network option: Liquid
  ///
  /// In en, this message translates to:
  /// **'Liquid Network'**
  String get exchangeDcaNetworkLiquid;

  /// Summary message describing the DCA configuration
  ///
  /// In en, this message translates to:
  /// **'You are buying {amount} every {frequency} via {network} as long as there are funds in your account.'**
  String exchangeDcaSummaryMessage(
    String amount,
    String frequency,
    String network,
  );

  /// Format for displaying address label and address
  ///
  /// In en, this message translates to:
  /// **'{addressLabel}: {address}'**
  String exchangeDcaAddressDisplay(String addressLabel, String address);

  /// KYC verification level: Light
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get exchangeKycLevelLight;

  /// KYC verification level: Limited
  ///
  /// In en, this message translates to:
  /// **'Limited'**
  String get exchangeKycLevelLimited;

  /// Title of the KYC completion card
  ///
  /// In en, this message translates to:
  /// **'Complete your KYC'**
  String get exchangeKycCardTitle;

  /// Subtitle explaining why to complete KYC
  ///
  /// In en, this message translates to:
  /// **'To remove transaction limits'**
  String get exchangeKycCardSubtitle;

  /// Label for the Buy action button on the wallet home screen
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get homeActionBuy;

  /// Label for the Sell action button on the wallet home screen
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get homeActionSell;

  /// Label for the Pay action button on the wallet home screen
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get homeActionPay;

  /// Label for the Transfer action button on the wallet home screen
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get homeActionTransfer;

  /// Accessible name of the Exchange home button that opens the price chart
  ///
  /// In en, this message translates to:
  /// **'Show price chart'**
  String get priceChartShowTooltip;

  /// Hint text for recipients search field
  ///
  /// In en, this message translates to:
  /// **'Search recipients by name or label'**
  String get recipientsSearchHint;

  /// App bar title for the recipients selection screen.
  ///
  /// In en, this message translates to:
  /// **'Select Recipient'**
  String get recipientsScreenTitle;

  /// Subtitle shown on the recipients screen prompting the user to choose a recipient.
  ///
  /// In en, this message translates to:
  /// **'Who are you paying?'**
  String get recipientsScreenSubtitle;

  /// Label for the tab to add a new recipient.
  ///
  /// In en, this message translates to:
  /// **'New Recipient'**
  String get recipientsTabNew;

  /// Label for the tab listing the user's saved fiat recipients.
  ///
  /// In en, this message translates to:
  /// **'My Fiat Recipients'**
  String get recipientsTabList;

  /// Label for the payout method selector in the new recipient form.
  ///
  /// In en, this message translates to:
  /// **'Payout method'**
  String get recipientsPayoutMethod;

  /// Label above the jurisdiction filter on the recipients list.
  ///
  /// In en, this message translates to:
  /// **'Filter by Jurisdiction:'**
  String get recipientsFilterByJurisdiction;

  /// Empty state message when no recipients match the current filters.
  ///
  /// In en, this message translates to:
  /// **'No recipients found.'**
  String get recipientsListEmpty;

  /// Continue button label used on recipient forms and the recipients list.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get recipientsContinue;

  /// Dropdown option to show recipients from all jurisdictions.
  ///
  /// In en, this message translates to:
  /// **'All Jurisdictions'**
  String get recipientsJurisdictionAll;

  /// Canada jurisdiction option in the jurisdictions dropdown.
  ///
  /// In en, this message translates to:
  /// **'🇨🇦 Canada'**
  String get recipientsJurisdictionCanada;

  /// Europe (SEPA) jurisdiction option in the jurisdictions dropdown.
  ///
  /// In en, this message translates to:
  /// **'🇪🇺 Europe (SEPA)'**
  String get recipientsJurisdictionEurope;

  /// Mexico jurisdiction option in the jurisdictions dropdown.
  ///
  /// In en, this message translates to:
  /// **'🇲🇽 Mexico'**
  String get recipientsJurisdictionMexico;

  /// Costa Rica jurisdiction option in the jurisdictions dropdown.
  ///
  /// In en, this message translates to:
  /// **'🇨🇷 Costa Rica'**
  String get recipientsJurisdictionCostaRica;

  /// Argentina jurisdiction option in the jurisdictions dropdown.
  ///
  /// In en, this message translates to:
  /// **'🇦🇷 Argentina'**
  String get recipientsJurisdictionArgentina;

  /// Colombia jurisdiction option in the jurisdictions dropdown.
  ///
  /// In en, this message translates to:
  /// **'🇨🇴 Colombia'**
  String get recipientsJurisdictionColombia;

  /// Display name for the Canadian email money transfer recipient type. Do not use the Interac trademark.
  ///
  /// In en, this message translates to:
  /// **'Email Money Transfer'**
  String get recipientsTypeInteracEmail;

  /// Display name for the Canadian Bill Payment recipient type.
  ///
  /// In en, this message translates to:
  /// **'Bill Payment'**
  String get recipientsTypeBillPayment;

  /// Display name for the Canadian Bank Transfer recipient type.
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get recipientsTypeBankTransfer;

  /// Display name for the European SEPA Transfer recipient type.
  ///
  /// In en, this message translates to:
  /// **'SEPA Transfer'**
  String get recipientsTypeSepa;

  /// Display name for the Mexican SPEI CLABE recipient type.
  ///
  /// In en, this message translates to:
  /// **'SPEI CLABE'**
  String get recipientsTypeSpeiClabe;

  /// Display name for the Mexican SPEI SMS recipient type.
  ///
  /// In en, this message translates to:
  /// **'SPEI SMS'**
  String get recipientsTypeSpeiSms;

  /// Display name for the Mexican SPEI debit card recipient type.
  ///
  /// In en, this message translates to:
  /// **'SPEI Card'**
  String get recipientsTypeSpeiCard;

  /// Display name for the Costa Rican SINPE IBAN USD recipient type.
  ///
  /// In en, this message translates to:
  /// **'SINPE IBAN (USD)'**
  String get recipientsTypeSinpeIbanUsd;

  /// Display name for the Costa Rican SINPE IBAN CRC recipient type.
  ///
  /// In en, this message translates to:
  /// **'SINPE IBAN (CRC)'**
  String get recipientsTypeSinpeIbanCrc;

  /// Display name for the Costa Rican SINPE Móvil recipient type.
  ///
  /// In en, this message translates to:
  /// **'SINPE Móvil'**
  String get recipientsTypeSinpeMovil;

  /// Display name for the Argentinian CBU/CVU bank account recipient type.
  ///
  /// In en, this message translates to:
  /// **'CBU/CVU Argentina'**
  String get recipientsTypeBankAccountAr;

  /// Display name for the Colombian bank account (COP) recipient type.
  ///
  /// In en, this message translates to:
  /// **'Bank Account COP'**
  String get recipientsTypeBankAccountCo;

  /// Display name for the Colombian Nequi recipient type.
  ///
  /// In en, this message translates to:
  /// **'Nequi'**
  String get recipientsTypeNequi;

  /// Info-row label for an email value on a recipient list tile.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get recipientsInfoEmail;

  /// Info-row label for a payee value on a recipient list tile.
  ///
  /// In en, this message translates to:
  /// **'Payee'**
  String get recipientsInfoPayee;

  /// Info-row label for a bank account value on a recipient list tile.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get recipientsInfoAccount;

  /// Info-row label for a phone number value on a recipient list tile.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get recipientsInfoPhone;

  /// Info-row label for a card value on a recipient list tile.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get recipientsInfoCard;

  /// Info-row label for the user-set label of a recipient on a list tile.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get recipientsInfoLabel;

  /// Validation error shown when a required recipient form field is empty.
  ///
  /// In en, this message translates to:
  /// **'This field can\'t be empty'**
  String get recipientsValidationFieldRequired;

  /// Label for the optional recipient label/nickname field in recipient forms.
  ///
  /// In en, this message translates to:
  /// **'Label (optional)'**
  String get recipientsLabelOptional;

  /// Hint text for the optional recipient label/nickname field.
  ///
  /// In en, this message translates to:
  /// **'Enter a label for this recipient'**
  String get recipientsLabelHint;

  /// Label for the recipient name field used in several recipient forms.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get recipientsFieldName;

  /// Hint text for the recipient name field.
  ///
  /// In en, this message translates to:
  /// **'Enter recipient name'**
  String get recipientsFieldNameHint;

  /// Longer label for the recipient name field used in the Colombia forms.
  ///
  /// In en, this message translates to:
  /// **'Name of the recipient'**
  String get recipientsFieldRecipientNameLabel;

  /// Label for the recipient phone number field.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get recipientsFieldPhoneNumber;

  /// Hint text for the recipient phone number field.
  ///
  /// In en, this message translates to:
  /// **'Enter phone number'**
  String get recipientsFieldPhoneNumberHint;

  /// Hint text for the SINPE Móvil phone number field.
  ///
  /// In en, this message translates to:
  /// **'8 digits without country code'**
  String get recipientsFieldSinpePhoneNumberHint;

  /// Label for the ID document type selector in Colombia recipient forms.
  ///
  /// In en, this message translates to:
  /// **'Recipient ID type'**
  String get recipientsFieldDocumentType;

  /// Hint text for the ID document number field.
  ///
  /// In en, this message translates to:
  /// **'Enter recipient ID number'**
  String get recipientsFieldDocumentNumberHint;

  /// Label for the account owner name field in SINPE recipient forms.
  ///
  /// In en, this message translates to:
  /// **'Owner Name'**
  String get recipientsFieldOwnerName;

  /// Hint text for the account owner name field.
  ///
  /// In en, this message translates to:
  /// **'Enter owner name'**
  String get recipientsFieldOwnerNameHint;

  /// Section header asking whose account is being added in recipient forms.
  ///
  /// In en, this message translates to:
  /// **'Who does this account belong to?'**
  String get recipientsAccountOwnerQuestion;

  /// Radio option indicating the recipient account belongs to the current user.
  ///
  /// In en, this message translates to:
  /// **'This is my account'**
  String get recipientsAccountOwnerMine;

  /// Radio option indicating the recipient account belongs to a third party.
  ///
  /// In en, this message translates to:
  /// **'This is someone else\'s account'**
  String get recipientsAccountOwnerSomeoneElse;

  /// Label for the IBAN field used in SEPA and SINPE forms.
  ///
  /// In en, this message translates to:
  /// **'IBAN'**
  String get recipientsFieldIban;

  /// Hint text for the IBAN field.
  ///
  /// In en, this message translates to:
  /// **'Enter IBAN'**
  String get recipientsFieldIbanHint;

  /// Label for the Mexican CLABE field.
  ///
  /// In en, this message translates to:
  /// **'CLABE'**
  String get recipientsFieldClabe;

  /// Hint text for the Mexican CLABE field.
  ///
  /// In en, this message translates to:
  /// **'Enter CLABE number'**
  String get recipientsFieldClabeHint;

  /// Label for the Argentinian CBU/CVU field.
  ///
  /// In en, this message translates to:
  /// **'CBU/CVU'**
  String get recipientsFieldCvuCbu;

  /// Hint text for the Argentinian CBU/CVU field.
  ///
  /// In en, this message translates to:
  /// **'Enter CVU/CBU number'**
  String get recipientsFieldCvuCbuHint;

  /// Label for the bank institution selector in the Colombia bank account form.
  ///
  /// In en, this message translates to:
  /// **'Bank Institution'**
  String get recipientsFieldBankInstitution;

  /// Placeholder option in the bank institution selector.
  ///
  /// In en, this message translates to:
  /// **'Select Bank Institution'**
  String get recipientsFieldBankInstitutionPlaceholder;

  /// Validation error when no bank institution is selected.
  ///
  /// In en, this message translates to:
  /// **'Please select a bank institution'**
  String get recipientsValidationBankInstitution;

  /// Label for the bank account type selector in the Colombia bank account form.
  ///
  /// In en, this message translates to:
  /// **'Account Type'**
  String get recipientsFieldAccountType;

  /// Bank account type option for savings.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get recipientsAccountTypeSavings;

  /// Bank account type option for checking.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get recipientsAccountTypeChecking;

  /// Label for the bank account number field in the Colombia bank account form.
  ///
  /// In en, this message translates to:
  /// **'Bank Account Number'**
  String get recipientsFieldBankAccountNumber;

  /// Hint text for the bank account number field.
  ///
  /// In en, this message translates to:
  /// **'Enter bank account number'**
  String get recipientsFieldBankAccountNumberHint;

  /// Colombia ID document type: citizenship card.
  ///
  /// In en, this message translates to:
  /// **'Cédula de Ciudadanía'**
  String get recipientsCopDocCc;

  /// Colombia ID document type: foreign resident ID.
  ///
  /// In en, this message translates to:
  /// **'Cédula de Extranjería'**
  String get recipientsCopDocCe;

  /// Colombia ID document type: tax identification number.
  ///
  /// In en, this message translates to:
  /// **'Número de Identificación Tributaria'**
  String get recipientsCopDocNit;

  /// Colombia ID document type: passport.
  ///
  /// In en, this message translates to:
  /// **'Passport'**
  String get recipientsCopDocPassport;

  /// Colombia ID document type: minor identity card.
  ///
  /// In en, this message translates to:
  /// **'Tarjeta de Identidad'**
  String get recipientsCopDocTi;

  /// Colombia ID document type: civil registry.
  ///
  /// In en, this message translates to:
  /// **'Registro Civil'**
  String get recipientsCopDocRegistroCivil;

  /// Label for the recipient cédula de ciudadanía number field.
  ///
  /// In en, this message translates to:
  /// **'Recipient cédula number'**
  String get recipientsCopDocCcRecipientNumber;

  /// Label for the recipient cédula de extranjería number field.
  ///
  /// In en, this message translates to:
  /// **'Recipient cédula de extranjería number'**
  String get recipientsCopDocCeRecipientNumber;

  /// Label for the recipient NIT number field.
  ///
  /// In en, this message translates to:
  /// **'Recipient tax ID number'**
  String get recipientsCopDocNitRecipientNumber;

  /// Label for the recipient passport number field.
  ///
  /// In en, this message translates to:
  /// **'Recipient passport number'**
  String get recipientsCopDocPassportRecipientNumber;

  /// Label for the recipient tarjeta de identidad number field.
  ///
  /// In en, this message translates to:
  /// **'Recipient identity card number'**
  String get recipientsCopDocTiRecipientNumber;

  /// Label for the recipient registro civil number field.
  ///
  /// In en, this message translates to:
  /// **'Recipient civil registry number'**
  String get recipientsCopDocRegistroCivilRecipientNumber;

  /// Label for the debit card number field in the SPEI Card form.
  ///
  /// In en, this message translates to:
  /// **'Debit Card Number'**
  String get recipientsFieldDebitCard;

  /// Hint text for the debit card number field.
  ///
  /// In en, this message translates to:
  /// **'Enter debit card number'**
  String get recipientsFieldDebitCardHint;

  /// Hint text for the owner name field while SINPE Móvil validation runs.
  ///
  /// In en, this message translates to:
  /// **'Owner name will appear here'**
  String get recipientsFieldOwnerNameSinpeHint;

  /// Validation error when a SINPE Móvil phone number includes the Costa Rica country code.
  ///
  /// In en, this message translates to:
  /// **'Remove the country code (+506). Enter only the 8-digit number'**
  String get recipientsValidationSinpePhoneCountryCode;

  /// Validation error when a SINPE Móvil phone number contains non-digit characters.
  ///
  /// In en, this message translates to:
  /// **'Use digits only (no letters or symbols)'**
  String get recipientsValidationSinpePhoneInvalidChars;

  /// Validation error when a SINPE Móvil phone number has fewer than 8 digits.
  ///
  /// In en, this message translates to:
  /// **'Enter all 8 digits of the phone number'**
  String get recipientsValidationSinpePhoneTooShort;

  /// Validation error when SINPE Móvil owner name is not validated yet.
  ///
  /// In en, this message translates to:
  /// **'Please validate the phone number'**
  String get recipientsValidationSinpeOwner;

  /// Label for the email address field in the Interac e-Transfer form.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get recipientsFieldEmailAddress;

  /// Hint text for the email address field.
  ///
  /// In en, this message translates to:
  /// **'Enter email address'**
  String get recipientsFieldEmailAddressHint;

  /// Label for the security question field in the Interac e-Transfer form.
  ///
  /// In en, this message translates to:
  /// **'Security Question'**
  String get recipientsFieldSecurityQuestion;

  /// Hint text for the security question field.
  ///
  /// In en, this message translates to:
  /// **'Enter security question (10-40 characters)'**
  String get recipientsFieldSecurityQuestionHint;

  /// Label for the security answer field in the Interac e-Transfer form.
  ///
  /// In en, this message translates to:
  /// **'Security Answer'**
  String get recipientsFieldSecurityAnswer;

  /// Hint text for the security answer field.
  ///
  /// In en, this message translates to:
  /// **'Enter security answer'**
  String get recipientsFieldSecurityAnswerHint;

  /// Validation error shown when the security question is shorter than 10 characters.
  ///
  /// In en, this message translates to:
  /// **'Security question must be at least 10 characters'**
  String get recipientsValidationSecurityQuestionMin;

  /// Character counter displayed below the security question field.
  ///
  /// In en, this message translates to:
  /// **'{count}/40 characters'**
  String recipientsCharCounter(int count);

  /// Label for the institution code field in SPEI SMS/Card forms.
  ///
  /// In en, this message translates to:
  /// **'Institution Code'**
  String get recipientsFieldInstitutionCode;

  /// Hint text for the institution code field.
  ///
  /// In en, this message translates to:
  /// **'Enter institution code'**
  String get recipientsFieldInstitutionCodeHint;

  /// Label for the institution number field in the Canadian bank transfer form.
  ///
  /// In en, this message translates to:
  /// **'Institution Number'**
  String get recipientsFieldInstitutionNumber;

  /// Hint text for the institution number field.
  ///
  /// In en, this message translates to:
  /// **'Enter institution number'**
  String get recipientsFieldInstitutionNumberHint;

  /// Label for the transit number field in the Canadian bank transfer form.
  ///
  /// In en, this message translates to:
  /// **'Transit Number'**
  String get recipientsFieldTransitNumber;

  /// Hint text for the transit number field.
  ///
  /// In en, this message translates to:
  /// **'Enter transit number'**
  String get recipientsFieldTransitNumberHint;

  /// Label for the account number field used in multiple recipient forms.
  ///
  /// In en, this message translates to:
  /// **'Account Number'**
  String get recipientsFieldAccountNumber;

  /// Hint text for the account number field.
  ///
  /// In en, this message translates to:
  /// **'Enter account number'**
  String get recipientsFieldAccountNumberHint;

  /// Label for the optional default comment field in the Canadian bank transfer form.
  ///
  /// In en, this message translates to:
  /// **'Default Comment (optional)'**
  String get recipientsFieldDefaultComment;

  /// Hint text for the optional default comment field.
  ///
  /// In en, this message translates to:
  /// **'Enter default comment'**
  String get recipientsFieldDefaultCommentHint;

  /// Checkbox label indicating the SEPA recipient is a corporate account.
  ///
  /// In en, this message translates to:
  /// **'Corporate account'**
  String get recipientsFieldCorporateAccount;

  /// Label for the first name field in the SEPA recipient form.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get recipientsFieldFirstName;

  /// Hint text for the first name field.
  ///
  /// In en, this message translates to:
  /// **'Enter first name'**
  String get recipientsFieldFirstNameHint;

  /// Label for the last name field in the SEPA recipient form.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get recipientsFieldLastName;

  /// Hint text for the last name field.
  ///
  /// In en, this message translates to:
  /// **'Enter last name'**
  String get recipientsFieldLastNameHint;

  /// Label for the corporate name field in the SEPA recipient form.
  ///
  /// In en, this message translates to:
  /// **'Corporate Name'**
  String get recipientsFieldCorporateName;

  /// Hint text for the corporate name field.
  ///
  /// In en, this message translates to:
  /// **'Enter corporate name'**
  String get recipientsFieldCorporateNameHint;

  /// Label for the biller search field in the Canadian bill payment form.
  ///
  /// In en, this message translates to:
  /// **'Biller Name'**
  String get recipientsFieldBillerName;

  /// Hint text for the biller search field.
  ///
  /// In en, this message translates to:
  /// **'Search and select a biller'**
  String get recipientsFieldBillerNameHint;

  /// Validation error shown when biller search input is too short.
  ///
  /// In en, this message translates to:
  /// **'Enter 3 or more characters to search'**
  String get recipientsValidationBillerSearchMin;

  /// Validation error shown when no biller is selected from the list.
  ///
  /// In en, this message translates to:
  /// **'Please select a biller from the list'**
  String get recipientsValidationBillerSelect;

  /// Label for the payee account number field in the bill payment form.
  ///
  /// In en, this message translates to:
  /// **'Payee Account Number'**
  String get recipientsFieldPayeeAccountNumber;

  /// Shown when the recipient list cannot be loaded from the API.
  ///
  /// In en, this message translates to:
  /// **'Your recipients could not be loaded. Please try again.'**
  String get recipientsErrorLoadFailed;

  /// Shown when creating a recipient fails.
  ///
  /// In en, this message translates to:
  /// **'This recipient could not be saved. Please check the details and try again.'**
  String get recipientsErrorSaveFailed;

  /// Shown when the SINPE phone number lookup fails.
  ///
  /// In en, this message translates to:
  /// **'We could not verify this phone number. Please check it and try again.'**
  String get recipientsErrorSinpeLookupFailed;

  /// Shown when searching the CAD biller directory fails.
  ///
  /// In en, this message translates to:
  /// **'Billers could not be searched. Please try again.'**
  String get recipientsErrorBillerSearchFailed;

  /// Shown when a recipients request could not reach the server or timed out.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get recipientsErrorNetwork;

  /// Hint under a recipients load failure. A pull-to-refresh affordance of the list screen, kept separate from the failure message itself.
  ///
  /// In en, this message translates to:
  /// **'Pull down to retry.'**
  String get recipientsListPullToRetry;

  /// Shown when a recipient saved successfully but the calling flow could not continue. Must not imply the save failed, or the user retries and creates a duplicate.
  ///
  /// In en, this message translates to:
  /// **'This recipient was saved, but we could not continue. Find them in your list to carry on.'**
  String get recipientsErrorSavedButNotSelected;

  /// Recipient type label for a Confidential SEPA recipient
  ///
  /// In en, this message translates to:
  /// **'Confidential SEPA'**
  String get recipientsTypeConfidentialSepa;

  /// Shown when the user cannot get a virtual IBAN because their KYC is insufficient or Confidential SEPA is not offered to them
  ///
  /// In en, this message translates to:
  /// **'You do not have the required permissions to access this funding option. Either your KYC is insufficient or this option is not available for your account'**
  String get recipientsErrorVirtualIbanNotAvailable;

  /// Shown when virtual IBAN creation is rejected because the user is not an EU resident
  ///
  /// In en, this message translates to:
  /// **'You need to be a resident of the European Union to activate Confidential SEPA.'**
  String get recipientsErrorEuResidencyRequired;

  /// Title of the Confidential SEPA activation screen while the recipient is being activated
  ///
  /// In en, this message translates to:
  /// **'Activating recipient'**
  String get recipientsConfidentialSepaActivatingTitle;

  /// Description of the Confidential SEPA activation screen while the recipient is being activated
  ///
  /// In en, this message translates to:
  /// **'Your recipient is being activated for Confidential SEPA. This may take a few minutes. We\'ll notify you when ready.'**
  String get recipientsConfidentialSepaActivatingDescription;

  /// Title of the Confidential SEPA activation screen when the recipient is not activated yet
  ///
  /// In en, this message translates to:
  /// **'Recipient not activated for Confidential SEPA'**
  String get recipientsConfidentialSepaNotActivatedTitle;

  /// Description of the Confidential SEPA activation screen when the recipient is not activated yet
  ///
  /// In en, this message translates to:
  /// **'This recipient is not activated for Confidential SEPA yet. We are activating it now. This may take a few minutes. We\'ll notify you when ready. You can use Instant and Regular SEPA instead.'**
  String get recipientsConfidentialSepaNotActivatedDescription;

  /// Title of the Confidential SEPA activation screen once the recipient is active
  ///
  /// In en, this message translates to:
  /// **'Recipient activated'**
  String get recipientsConfidentialSepaActivatedTitle;

  /// Description of the Confidential SEPA activation screen once the recipient is active
  ///
  /// In en, this message translates to:
  /// **'Your recipient is now active for Confidential SEPA.'**
  String get recipientsConfidentialSepaActivatedDescription;

  /// Button that pays the recipient through regular SEPA instead of Confidential SEPA
  ///
  /// In en, this message translates to:
  /// **'Use Instant and Regular SEPA instead'**
  String get recipientsConfidentialSepaUseRegularSepa;

  /// Button that leaves the activation screen and returns to the app home; activation continues and the user is notified when ready
  ///
  /// In en, this message translates to:
  /// **'Return Home'**
  String get recipientsReturnHome;

  /// Title of the virtual IBAN onboarding screen
  ///
  /// In en, this message translates to:
  /// **'Activate Confidential SEPA?'**
  String get recipientsVirtualIbanIntroTitle;

  /// Badge that marks Confidential SEPA as a new feature
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get recipientsVirtualIbanNewBadge;

  /// Explains what the virtual IBAN is on the onboarding screen
  ///
  /// In en, this message translates to:
  /// **'Fund your account privately using a personal virtual IBAN in your own name. It\'s free.'**
  String get recipientsVirtualIbanIntroDescription;

  /// Bullet point: a deposit appears as a transfer to yourself
  ///
  /// In en, this message translates to:
  /// **'When sending funds to Bull Bitcoin from your bank, it appears as a transfer to yourself.'**
  String get recipientsVirtualIbanIntroSelfTransfer;

  /// Bullet point: no transfer code is needed
  ///
  /// In en, this message translates to:
  /// **'No transfer code required.'**
  String get recipientsVirtualIbanIntroNoTransferCode;

  /// Title of the warning that the bank account name must match
  ///
  /// In en, this message translates to:
  /// **'Important: Name Matching Required'**
  String get recipientsVirtualIbanNameWarningTitle;

  /// Warning that a transfer from a bank account with a different name is returned
  ///
  /// In en, this message translates to:
  /// **'Bank account name must exactly match your Bull Bitcoin virtual IBAN name, or the transfer will be returned automatically. Names don\'t match? Contact support.'**
  String get recipientsVirtualIbanNameWarningDescription;

  /// Label above the name the virtual IBAN is issued in
  ///
  /// In en, this message translates to:
  /// **'Account Owner Name'**
  String get recipientsVirtualIbanAccountOwnerName;

  /// Checkbox to confirm the name matches the user's bank accounts
  ///
  /// In en, this message translates to:
  /// **'I confirm the name matches my bank account(s)'**
  String get recipientsVirtualIbanNameConfirmation;

  /// Button that creates the virtual IBAN
  ///
  /// In en, this message translates to:
  /// **'Activate Confidential SEPA'**
  String get recipientsVirtualIbanActivate;

  /// Title while the virtual IBAN is being created
  ///
  /// In en, this message translates to:
  /// **'Activating Confidential SEPA...'**
  String get recipientsVirtualIbanActivatingTitle;

  /// Description while the virtual IBAN is being created
  ///
  /// In en, this message translates to:
  /// **'Creating your virtual IBAN. This may take a few minutes. We\'ll notify you when ready.'**
  String get recipientsVirtualIbanActivatingDescription;

  /// Title once the virtual IBAN is active
  ///
  /// In en, this message translates to:
  /// **'Confidential SEPA Activated'**
  String get recipientsVirtualIbanActivatedTitle;

  /// Description once the virtual IBAN is active, before creating a Confidential SEPA recipient for a withdrawal
  ///
  /// In en, this message translates to:
  /// **'You can now use your personal virtual IBAN to withdraw money privately.'**
  String get recipientsVirtualIbanActivatedDescription;

  /// Toast shown after copying a virtual IBAN detail
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get recipientsVirtualIbanCopied;

  /// Button that leaves the virtual IBAN deposit details
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get recipientsVirtualIbanDone;

  /// Label of the name to use as recipient when depositing to the virtual IBAN
  ///
  /// In en, this message translates to:
  /// **'Recipient name'**
  String get recipientsVirtualIbanRecipientName;

  /// Label of the virtual IBAN account number
  ///
  /// In en, this message translates to:
  /// **'Virtual IBAN Account Number'**
  String get recipientsVirtualIbanIbanLabel;

  /// Label of the country of the virtual IBAN account
  ///
  /// In en, this message translates to:
  /// **'Bank account country'**
  String get recipientsVirtualIbanCountry;

  /// Label of the BIC code of the virtual IBAN account
  ///
  /// In en, this message translates to:
  /// **'BIC code'**
  String get recipientsVirtualIbanBic;

  /// Description once the virtual IBAN is active, when started from funding
  ///
  /// In en, this message translates to:
  /// **'You can now use your personal virtual IBAN to deposit money privately.'**
  String get recipientsVirtualIbanActivatedFundingDescription;

  /// Button that shows the virtual IBAN deposit details
  ///
  /// In en, this message translates to:
  /// **'Show my virtual IBAN details'**
  String get recipientsVirtualIbanShowDetails;

  /// Explains how to deposit with the virtual IBAN
  ///
  /// In en, this message translates to:
  /// **'Fund your account privately using a personal virtual IBAN in your own name. The deposit will appear as a payment to yourself, with no transfer code required.'**
  String get recipientsVirtualIbanDetailsDescription;

  /// Label of the address of the bank that holds the virtual IBAN
  ///
  /// In en, this message translates to:
  /// **'Bank address'**
  String get recipientsVirtualIbanBankAddress;

  /// Explains when the bank address of the virtual IBAN is needed
  ///
  /// In en, this message translates to:
  /// **'The official bank address, in case your bank asks for it.'**
  String get recipientsVirtualIbanBankAddressHelp;

  /// Hint under the read-only account owner name on the Confidential SEPA recipient form
  ///
  /// In en, this message translates to:
  /// **'Names must match between your bank and virtual IBAN accounts or transfers will be returned automatically.'**
  String get recipientsConfidentialSepaNameMustMatchHint;

  /// Label for the destination bank account IBAN on the SEPA recipient form
  ///
  /// In en, this message translates to:
  /// **'Bank account number (IBAN)'**
  String get recipientsFieldBankAccountIban;

  /// Explanation of Confidential SEPA in the payout method selector
  ///
  /// In en, this message translates to:
  /// **'Withdrawals appear as a self-transfer with your account name'**
  String get recipientsTypeConfidentialSepaDescription;

  /// AppBar title for withdraw amount screen
  ///
  /// In en, this message translates to:
  /// **'Withdraw fiat'**
  String get withdrawAmountTitle;

  /// Continue button on amount screen
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get withdrawAmountContinue;

  /// Title on confirmation screen
  ///
  /// In en, this message translates to:
  /// **'Confirm withdrawal'**
  String get withdrawConfirmTitle;

  /// Field label for recipient name
  ///
  /// In en, this message translates to:
  /// **'Recipient name'**
  String get withdrawConfirmRecipientName;

  /// Field label for withdrawal amount
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get withdrawConfirmAmount;

  /// Field label for email (Interac)
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get withdrawConfirmEmail;

  /// Field label for payee (Bill Payment)
  ///
  /// In en, this message translates to:
  /// **'Payee'**
  String get withdrawConfirmPayee;

  /// Field label for bank account
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get withdrawConfirmAccount;

  /// Field label for IBAN
  ///
  /// In en, this message translates to:
  /// **'IBAN'**
  String get withdrawConfirmIban;

  /// Field label for CLABE (Mexico)
  ///
  /// In en, this message translates to:
  /// **'CLABE'**
  String get withdrawConfirmClabe;

  /// Field label for phone number
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get withdrawConfirmPhone;

  /// Field label for debit card
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get withdrawConfirmCard;

  /// Button to confirm withdrawal
  ///
  /// In en, this message translates to:
  /// **'Confirm withdrawal'**
  String get withdrawConfirmButton;

  /// Title shown when withdrawal is successfully initiated
  ///
  /// In en, this message translates to:
  /// **'Withdrawal Initiated'**
  String get withdrawSuccessTitle;

  /// Button label to view order details after withdrawal
  ///
  /// In en, this message translates to:
  /// **'Order details'**
  String get withdrawSuccessOrderDetails;

  /// Default label for bank account in confirmation screen
  ///
  /// In en, this message translates to:
  /// **'Bank account'**
  String get withdrawConfirmBankAccount;

  /// Question asking about account ownership
  ///
  /// In en, this message translates to:
  /// **'Who does this account belong to?'**
  String get withdrawOwnershipQuestion;

  /// Option indicating the account belongs to the user
  ///
  /// In en, this message translates to:
  /// **'This is my account'**
  String get withdrawOwnershipMyAccount;

  /// Option indicating the account belongs to someone else
  ///
  /// In en, this message translates to:
  /// **'This is someone else\'s account'**
  String get withdrawOwnershipOtherAccount;

  /// Error message for unauthenticated user during withdraw
  ///
  /// In en, this message translates to:
  /// **'You are not authenticated. Please log in to continue.'**
  String get withdrawUnauthenticatedError;

  /// Shown when the withdrawal amount is under the account minimum. Names the bound the exchange reported so the user can correct the amount.
  ///
  /// In en, this message translates to:
  /// **'Minimum amount is {amount} {currency}'**
  String withdrawBelowMinAmountError(String amount, String currency);

  /// Shown when the withdrawal amount is over the account maximum. Names the bound the exchange reported so the user can correct the amount.
  ///
  /// In en, this message translates to:
  /// **'Maximum amount is {amount} {currency}'**
  String withdrawAboveMaxAmountError(String amount, String currency);

  /// Title for the email money transfer security question and answer screen.
  ///
  /// In en, this message translates to:
  /// **'Transfer security details'**
  String get withdrawInteracSecurityDetailsTitle;

  /// Checkbox label for saving Interac security details on the recipient.
  ///
  /// In en, this message translates to:
  /// **'Save these details as default'**
  String get withdrawInteracSaveAsDefault;

  /// Validation error for an Interac security question outside the allowed length.
  ///
  /// In en, this message translates to:
  /// **'Security question must be 3-40 characters'**
  String get withdrawInteracSecurityQuestionLengthError;

  /// Validation error for an Interac security answer outside the allowed length.
  ///
  /// In en, this message translates to:
  /// **'Security answer must be 3-40 characters'**
  String get withdrawInteracSecurityAnswerLengthError;

  /// Validation error for unsupported Interac security answer characters.
  ///
  /// In en, this message translates to:
  /// **'Use letters, numbers, or hyphens without spaces'**
  String get withdrawInteracSecurityAnswerFormatError;

  /// Generic error message shown when a withdrawal could not be completed for any unrecognized reason, including connectivity failures, so it must not blame the amount or the recipient
  ///
  /// In en, this message translates to:
  /// **'Your withdrawal could not be completed right now. Please try again or contact support.'**
  String get withdrawUnexpectedError;

  /// Shown when a Confidential SEPA withdrawal is refused because the recipient is still not activated after activation was offered
  ///
  /// In en, this message translates to:
  /// **'Please activate the confidential payment option for this SEPA recipient.'**
  String get withdrawConfidentialSepaNotActivatedError;

  /// Title for the Limit Orders feature
  ///
  /// In en, this message translates to:
  /// **'Limit orders'**
  String get limitOrdersTitle;

  /// Heading above active Limit Orders
  ///
  /// In en, this message translates to:
  /// **'Active limit orders'**
  String get limitOrdersActiveTitle;

  /// Action to create another Limit Order
  ///
  /// In en, this message translates to:
  /// **'Create new'**
  String get limitOrdersCreateNew;

  /// Shown when the five-active-Limit-Order cap has been reached
  ///
  /// In en, this message translates to:
  /// **'Cancel an active order before creating another one.'**
  String get limitOrdersMaximumActiveHint;

  /// Summary of a Limit Order target price
  ///
  /// In en, this message translates to:
  /// **'Buy at {price}'**
  String limitOrdersBuyAt(String price);

  /// Action to cancel all active Limit Orders
  ///
  /// In en, this message translates to:
  /// **'Cancel all'**
  String get limitOrdersCancelAll;

  /// Title of the cancel-all Limit Orders confirmation
  ///
  /// In en, this message translates to:
  /// **'Cancel all active limit orders?'**
  String get limitOrdersCancelAllTitle;

  /// Warning shown before all active Limit Orders are cancelled
  ///
  /// In en, this message translates to:
  /// **'This is permanent. None of these orders will execute after cancellation.'**
  String get limitOrdersCancelAllMessage;

  /// Confirmation action in Limit Order dialogs
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get limitOrdersDialogConfirm;

  /// Closes a completed Limit Order screen
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get limitOrdersDone;

  /// Label for the Limit Order target price
  ///
  /// In en, this message translates to:
  /// **'Target price'**
  String get limitOrdersTargetPrice;

  /// Label for the Limit Order fiat amount
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get limitOrdersFiatAmount;

  /// Estimated user buy price after spread
  ///
  /// In en, this message translates to:
  /// **'Estimated buy price'**
  String get limitOrdersEstimatedBuyPrice;

  /// Title of the Limit Order details screen
  ///
  /// In en, this message translates to:
  /// **'Limit order details'**
  String get limitOrderDetailsTitle;

  /// Limit Order status label
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get limitOrderDetailsStatus;

  /// Limit Order number label
  ///
  /// In en, this message translates to:
  /// **'Order number'**
  String get limitOrderDetailsNumber;

  /// Limit Order payout address label
  ///
  /// In en, this message translates to:
  /// **'Payout address'**
  String get limitOrderDetailsAddress;

  /// Limit Order creation date label
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get limitOrderDetailsCreated;

  /// Limit Order expiry date label
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get limitOrderDetailsExpires;

  /// Action to cancel one active Limit Order
  ///
  /// In en, this message translates to:
  /// **'Cancel limit order'**
  String get limitOrderCancel;

  /// Title of the single Limit Order cancellation dialog
  ///
  /// In en, this message translates to:
  /// **'Cancel this limit order?'**
  String get limitOrderCancelTitle;

  /// Warning before one Limit Order is cancelled
  ///
  /// In en, this message translates to:
  /// **'Cancellation is permanent and this order will no longer execute.'**
  String get limitOrderCancelMessage;

  /// Active Limit Order status
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get limitOrderStatusActive;

  /// Executed Limit Order status
  ///
  /// In en, this message translates to:
  /// **'Executed'**
  String get limitOrderStatusExecuted;

  /// Cancelled Limit Order status
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get limitOrderStatusCancelled;

  /// Expired Limit Order status
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get limitOrderStatusExpired;

  /// Failed or unknown Limit Order status
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get limitOrderStatusFailed;

  /// Shown when Limit Order account data is unavailable
  ///
  /// In en, this message translates to:
  /// **'Your Bull Bitcoin account or balances could not be loaded. Please try again.'**
  String get limitOrdersAccountUnavailableError;

  /// Shown when a Limit Order no longer exists
  ///
  /// In en, this message translates to:
  /// **'This limit order could not be found.'**
  String get limitOrderNotFoundError;

  /// Shown when Limit Orders cannot be loaded
  ///
  /// In en, this message translates to:
  /// **'Limit orders could not be loaded. Please try again.'**
  String get limitOrdersLoadError;

  /// Shown when one or all Limit Orders cannot be cancelled
  ///
  /// In en, this message translates to:
  /// **'The limit order could not be cancelled. Please try again.'**
  String get limitOrderCancellationError;

  /// Label for the estimated bitcoin amount row on the limit order details screen
  ///
  /// In en, this message translates to:
  /// **'Estimated bitcoin'**
  String get limitOrderDetailsEstimatedBitcoin;

  /// Shown when the backend rejects a sixth active Limit Order
  ///
  /// In en, this message translates to:
  /// **'You already have five active limit orders. Cancel one before creating another.'**
  String get limitOrdersMaximumActiveError;

  /// Shown when the backend rejects a Limit Order payout address
  ///
  /// In en, this message translates to:
  /// **'The selected payout address is not valid.'**
  String get limitOrderInvalidAddressError;

  /// Shown when a Limit Order cannot be created
  ///
  /// In en, this message translates to:
  /// **'The limit order could not be created. Please try again.'**
  String get limitOrderCreationError;

  /// Title for the log out option in exchange settings
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get exchangeSettingsLogOutTitle;

  /// Title for logout confirmation bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Confirm Logout'**
  String get logoutConfirmationTitle;

  /// Description text for logout confirmation bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out of your Bull Bitcoin account? You will need to log in again to access exchange features.'**
  String get logoutConfirmationDescription;

  /// Cancel button label for logout confirmation
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get logoutConfirmationCancel;

  /// Logout button label for logout confirmation
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logoutConfirmationLogout;

  /// Label for the delete account option in exchange settings
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get exchangeSettingsDeleteAccountTitle;

  /// Title for the delete account confirmation bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountConfirmationTitle;

  /// Description for the delete account confirmation bottom sheet
  ///
  /// In en, this message translates to:
  /// **'This will send an account deletion request to our support team. Your account will be deleted within 5 working days.'**
  String get deleteAccountConfirmationDescription;

  /// Cancel button label for delete account confirmation
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get deleteAccountConfirmationCancel;

  /// Delete button label for delete account confirmation
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountConfirmationDelete;

  /// Title for the delete account success bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Account Deletion Requested'**
  String get deleteAccountSuccessTitle;

  /// Description for the delete account success bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Your account deletion request has been made. It will be processed within 5 working days.'**
  String get deleteAccountSuccessDescription;

  /// Close button label for delete account success bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get deleteAccountSuccessClose;

  /// Label for amount input field in buy flow
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get buyEnterAmount;

  /// Label for payment method dropdown
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get buyPaymentMethod;

  /// Button to fill maximum amount
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get buyMax;

  /// Label for wallet selection dropdown
  ///
  /// In en, this message translates to:
  /// **'Select wallet'**
  String get buySelectWallet;

  /// Label for bitcoin address input field
  ///
  /// In en, this message translates to:
  /// **'Enter bitcoin address'**
  String get buyEnterBitcoinAddress;

  /// Placeholder hint for bitcoin address input
  ///
  /// In en, this message translates to:
  /// **'BC1QYL7J673H…6Y6ALV70M0'**
  String get buyBitcoinAddressHint;

  /// Button to confirm purchase
  ///
  /// In en, this message translates to:
  /// **'Confirm purchase'**
  String get buyConfirmPurchase;

  /// Success message with amount bought and the fiat amount debited
  ///
  /// In en, this message translates to:
  /// **'You bought {amount} with {fiatAmount}'**
  String buyYouBought(String amount, String fiatAmount);

  /// Text before countdown timer for payout
  ///
  /// In en, this message translates to:
  /// **'Your payout will be sent in '**
  String get buyPayoutWillBeSentIn;

  /// Button to view order details
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get buyViewDetails;

  /// Title for transaction acceleration option
  ///
  /// In en, this message translates to:
  /// **'Accelerate Transaction'**
  String get buyAccelerateTransaction;

  /// Subtitle for acceleration option
  ///
  /// In en, this message translates to:
  /// **'Get it confirmed faster'**
  String get buyGetConfirmedFaster;

  /// Title for express withdrawal confirmation screen
  ///
  /// In en, this message translates to:
  /// **'Confirm express withdrawal'**
  String get buyConfirmExpressWithdrawal;

  /// Explanation of network fees for express withdrawal
  ///
  /// In en, this message translates to:
  /// **'The Bitcoin network fee will be deducted from the amount you receive and collected by the Bitcoin miners'**
  String get buyNetworkFeeExplanation;

  /// Label for network fees amount
  ///
  /// In en, this message translates to:
  /// **'Network fees'**
  String get buyNetworkFees;

  /// Label for estimated fee value in fiat
  ///
  /// In en, this message translates to:
  /// **'Estimated fee value'**
  String get buyEstimatedFeeValue;

  /// Label for network fee rate
  ///
  /// In en, this message translates to:
  /// **'Network fee rate'**
  String get buyNetworkFeeRate;

  /// Label for estimated confirmation time
  ///
  /// In en, this message translates to:
  /// **'Confirmation time'**
  String get buyConfirmationTime;

  /// Value for estimated confirmation time
  ///
  /// In en, this message translates to:
  /// **'~10 minutes'**
  String get buyConfirmationTimeValue;

  /// Button to wait for free (slower) withdrawal
  ///
  /// In en, this message translates to:
  /// **'Wait for free withdrawal'**
  String get buyWaitForFreeWithdrawal;

  /// Button to confirm express withdrawal
  ///
  /// In en, this message translates to:
  /// **'Confirm express'**
  String get buyConfirmExpress;

  /// Success message for accelerated transaction
  ///
  /// In en, this message translates to:
  /// **'Bitcoin sent!'**
  String get buyBitcoinSent;

  /// Additional success message for accelerated transaction
  ///
  /// In en, this message translates to:
  /// **'That was fast, wasn\'t it?'**
  String get buyThatWasFast;

  /// Default label for Bitcoin wallets when used as the default wallet
  ///
  /// In en, this message translates to:
  /// **'Secure Bitcoin'**
  String get globalDefaultBitcoinWalletLabel;

  /// Default label for Liquid/instant payments wallets when used as the default wallet
  ///
  /// In en, this message translates to:
  /// **'Instant payments'**
  String get globalDefaultLiquidWalletLabel;

  /// Success screen title after DCA is activated
  ///
  /// In en, this message translates to:
  /// **'Recurring Buy is Active!'**
  String get dcaSuccessTitle;

  /// Success message for hourly frequency
  ///
  /// In en, this message translates to:
  /// **'You will buy {amount} every hour'**
  String dcaSuccessMessageHourly(String amount);

  /// Success message for daily frequency
  ///
  /// In en, this message translates to:
  /// **'You will buy {amount} every day'**
  String dcaSuccessMessageDaily(String amount);

  /// Success message for weekly frequency
  ///
  /// In en, this message translates to:
  /// **'You will buy {amount} every week'**
  String dcaSuccessMessageWeekly(String amount);

  /// Success message for monthly frequency
  ///
  /// In en, this message translates to:
  /// **'You will buy {amount} every month'**
  String dcaSuccessMessageMonthly(String amount);

  /// Button label to return to exchange home screen
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get dcaBackToHomeButton;

  /// AppBar title for wallet selection screen
  ///
  /// In en, this message translates to:
  /// **'Choose Bitcoin Wallet'**
  String get dcaChooseWalletTitle;

  /// Explanation text at the top of wallet selection screen
  ///
  /// In en, this message translates to:
  /// **'Bitcoin purchases will be placed automatically per this schedule.'**
  String get dcaWalletSelectionDescription;

  /// Form validation error when no network is selected
  ///
  /// In en, this message translates to:
  /// **'Please select a network'**
  String get dcaNetworkValidationError;

  /// Label for Lightning address text input field
  ///
  /// In en, this message translates to:
  /// **'Enter Lightning Address'**
  String get dcaEnterLightningAddressLabel;

  /// Checkbox label to use default Lightning address
  ///
  /// In en, this message translates to:
  /// **'Use my default Lightning address.'**
  String get dcaUseDefaultLightningAddress;

  /// Button label to proceed to confirmation screen
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get dcaWalletSelectionContinueButton;

  /// Label above frequency selection radio buttons
  ///
  /// In en, this message translates to:
  /// **'Select Frequency'**
  String get dcaSelectFrequencyLabel;

  /// Label above wallet type selection radio buttons
  ///
  /// In en, this message translates to:
  /// **'Select Bitcoin Wallet Type'**
  String get dcaSelectWalletTypeLabel;

  /// Radio button option for Bitcoin wallet
  ///
  /// In en, this message translates to:
  /// **'Bitcoin (BTC)'**
  String get dcaWalletTypeBitcoin;

  /// Radio button option for Lightning wallet
  ///
  /// In en, this message translates to:
  /// **'Lightning Network (LN)'**
  String get dcaWalletTypeLightning;

  /// Radio button option for Liquid wallet
  ///
  /// In en, this message translates to:
  /// **'Liquid (LBTC)'**
  String get dcaWalletTypeLiquid;

  /// Subtitle/description for Bitcoin wallet option
  ///
  /// In en, this message translates to:
  /// **'Minimum 0.001 BTC'**
  String get dcaWalletBitcoinSubtitle;

  /// Subtitle/description for Lightning wallet option
  ///
  /// In en, this message translates to:
  /// **'Requires compatible wallet, maximum 0.25 BTC'**
  String get dcaWalletLightningSubtitle;

  /// Subtitle/description for Liquid wallet option
  ///
  /// In en, this message translates to:
  /// **'Requires compatible wallet'**
  String get dcaWalletLiquidSubtitle;

  /// AppBar title for DCA setup screen
  ///
  /// In en, this message translates to:
  /// **'Set Recurring Buy'**
  String get dcaSetupTitle;

  /// Insufficient balance error title
  ///
  /// In en, this message translates to:
  /// **'Insufficient Balance'**
  String get dcaSetupInsufficientBalance;

  /// Insufficient balance error message
  ///
  /// In en, this message translates to:
  /// **'You do not have enough balance to create this order.'**
  String get dcaSetupInsufficientBalanceMessage;

  /// Button to fund account
  ///
  /// In en, this message translates to:
  /// **'Fund your account'**
  String get dcaSetupFundAccount;

  /// DCA schedule explanation
  ///
  /// In en, this message translates to:
  /// **'Bitcoin purchases will be placed automatically per this schedule.'**
  String get dcaSetupScheduleMessage;

  /// Frequency validation error
  ///
  /// In en, this message translates to:
  /// **'Please select a frequency'**
  String get dcaSetupFrequencyError;

  /// Continue button on DCA setup
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get dcaSetupContinue;

  /// AppBar title for DCA confirmation screen
  ///
  /// In en, this message translates to:
  /// **'Confirm Recurring Buy'**
  String get dcaConfirmTitle;

  /// DCA auto-placement message
  ///
  /// In en, this message translates to:
  /// **'Buy orders will be placed automatically per these settings. You can disable them anytime.'**
  String get dcaConfirmAutoMessage;

  /// Field label for frequency
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get dcaConfirmFrequency;

  /// Hourly frequency label
  ///
  /// In en, this message translates to:
  /// **'Every hour'**
  String get dcaConfirmFrequencyHourly;

  /// Daily frequency label
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get dcaConfirmFrequencyDaily;

  /// Weekly frequency label
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get dcaConfirmFrequencyWeekly;

  /// Monthly frequency label
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get dcaConfirmFrequencyMonthly;

  /// Field label for amount
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get dcaConfirmAmount;

  /// Field label for payment method
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get dcaConfirmPaymentMethod;

  /// Payment method balance format
  ///
  /// In en, this message translates to:
  /// **'{currency} balance'**
  String dcaConfirmPaymentBalance(String currency);

  /// Field label for order type
  ///
  /// In en, this message translates to:
  /// **'Order type'**
  String get dcaConfirmOrderType;

  /// Order type value
  ///
  /// In en, this message translates to:
  /// **'Recurring buy'**
  String get dcaConfirmOrderTypeValue;

  /// Field label for network
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get dcaConfirmNetwork;

  /// Bitcoin network label
  ///
  /// In en, this message translates to:
  /// **'Bitcoin'**
  String get dcaConfirmNetworkBitcoin;

  /// Lightning network label
  ///
  /// In en, this message translates to:
  /// **'Lightning'**
  String get dcaConfirmNetworkLightning;

  /// Liquid network label
  ///
  /// In en, this message translates to:
  /// **'Liquid'**
  String get dcaConfirmNetworkLiquid;

  /// Field label for Lightning address
  ///
  /// In en, this message translates to:
  /// **'Lightning address'**
  String get dcaConfirmLightningAddress;

  /// Continue button on DCA confirmation
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get dcaConfirmContinue;

  /// AppBar title for buy input screen
  ///
  /// In en, this message translates to:
  /// **'Buy Bitcoin'**
  String get buyInputTitle;

  /// Minimum amount error message
  ///
  /// In en, this message translates to:
  /// **'You should buy at least'**
  String get buyInputMinAmountError;

  /// Maximum amount error message
  ///
  /// In en, this message translates to:
  /// **'You can\'t buy more than'**
  String get buyInputMaxAmountError;

  /// KYC pending info card title
  ///
  /// In en, this message translates to:
  /// **'KYC ID Verification Pending'**
  String get buyInputKycPending;

  /// KYC pending info card message
  ///
  /// In en, this message translates to:
  /// **'You must complete ID Verification first'**
  String get buyInputKycMessage;

  /// Button to complete KYC
  ///
  /// In en, this message translates to:
  /// **'Complete KYC'**
  String get buyInputCompleteKyc;

  /// Insufficient balance info card title
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance'**
  String get buyInputInsufficientBalance;

  /// Insufficient balance message
  ///
  /// In en, this message translates to:
  /// **'You do not have enough balance to create this order.'**
  String get buyInputInsufficientBalanceMessage;

  /// Button to fund account
  ///
  /// In en, this message translates to:
  /// **'Fund your account'**
  String get buyInputFundAccount;

  /// Continue button on buy input
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get buyInputContinue;

  /// AppBar title for buy confirmation screen
  ///
  /// In en, this message translates to:
  /// **'Buy Bitcoin'**
  String get buyConfirmTitle;

  /// Field label for payment amount
  ///
  /// In en, this message translates to:
  /// **'You pay'**
  String get buyConfirmYouPay;

  /// Field label for receive amount
  ///
  /// In en, this message translates to:
  /// **'You receive'**
  String get buyConfirmYouReceive;

  /// Field label for Bitcoin price
  ///
  /// In en, this message translates to:
  /// **'Bitcoin Price'**
  String get buyConfirmBitcoinPrice;

  /// Field label for the wallet a buy pays out to
  ///
  /// In en, this message translates to:
  /// **'Payout wallet'**
  String get buyConfirmPayoutWallet;

  /// Field label for payout method
  ///
  /// In en, this message translates to:
  /// **'Payout method'**
  String get buyConfirmPayoutMethod;

  /// Payout method for buys paid out over the Liquid network
  ///
  /// In en, this message translates to:
  /// **'L-BTC on Liquid'**
  String get buyPayoutMethodLiquid;

  /// Payout method for buys paid out over the Bitcoin network
  ///
  /// In en, this message translates to:
  /// **'BTC on Bitcoin chain'**
  String get buyPayoutMethodBitcoin;

  /// External wallet payout method
  ///
  /// In en, this message translates to:
  /// **'External Bitcoin wallet'**
  String get buyConfirmExternalWallet;

  /// Awaiting confirmation label
  ///
  /// In en, this message translates to:
  /// **'Awaiting confirmation '**
  String get buyConfirmAwaitingConfirmation;

  /// Error message for unauthenticated user during buy
  ///
  /// In en, this message translates to:
  /// **'You are not authenticated. Please log in to continue.'**
  String get buyUnauthenticatedError;

  /// Error message for amount below minimum during buy
  ///
  /// In en, this message translates to:
  /// **'You are trying to buy below the minimum amount.'**
  String get buyBelowMinAmountError;

  /// Error message for amount above maximum during buy
  ///
  /// In en, this message translates to:
  /// **'You are trying to buy above the maximum amount.'**
  String get buyAboveMaxAmountError;

  /// Generic error message shown when a buy order could not be created for any unrecognized reason, including connectivity failures, so it must not blame the amount
  ///
  /// In en, this message translates to:
  /// **'Your order could not be created right now. Please try again or contact support.'**
  String get buyUnexpectedError;

  /// Shown when the exchange account summary cannot be loaded, so DCA setup cannot start. Deliberately covers three causes the boundary cannot tell apart: not logged in, no connection, and a backend error.
  ///
  /// In en, this message translates to:
  /// **'Could not load your account. Check your connection, make sure you are logged in, and try again.'**
  String get dcaAccountUnavailableError;

  /// Shown when Lightning was chosen as the DCA payout network but no lightning address was provided.
  ///
  /// In en, this message translates to:
  /// **'Enter a Lightning address to receive your purchases.'**
  String get dcaLightningAddressRequiredError;

  /// Shown when no default wallet exists for the chosen DCA network or generating a receive address failed.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare a receiving address in your wallet. Please try again.'**
  String get dcaReceiveAddressError;

  /// Shown when the exchange rejects creating the recurring buy order.
  ///
  /// In en, this message translates to:
  /// **'The recurring buy could not be created. Please try again later.'**
  String get dcaOrderCreationError;

  /// Shown while a payjoin negotiation is still running, before its outcome is known
  ///
  /// In en, this message translates to:
  /// **'Payjoin in progress'**
  String get payjoinInProgress;

  /// Shown when the payjoin negotiation completed and the payjoin transaction was broadcast
  ///
  /// In en, this message translates to:
  /// **'Payjoin succeeded'**
  String get payjoinSucceeded;

  /// Shown on a buy when the payout did not use payjoin and arrived as a plain transaction
  ///
  /// In en, this message translates to:
  /// **'Bitcoin sent to your wallet via regular send'**
  String get payjoinBuyRegularSend;

  /// Label of the toggle that lets the customer opt out of payjoin before confirming an order
  ///
  /// In en, this message translates to:
  /// **'Use payjoin'**
  String get payjoinUseToggle;

  /// Hint for the lightning-address field showing the expected lightning address format
  ///
  /// In en, this message translates to:
  /// **'you@domain.com'**
  String get limitOrdersLightningAddressHint;

  /// Shown on the buy, sell or pay confirmation when the price lock lapsed and the bounded quote refreshes brought no usable price back; nothing was paid.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t get a fresh price. Try again, or go back and start a new order.'**
  String get exchangeQuoteUnavailableError;

  /// Shown on the buy confirmation when the price lock expired before the order was confirmed; nothing was bought.
  ///
  /// In en, this message translates to:
  /// **'This price has expired. A new one is being loaded; check it before confirming.'**
  String get buyQuoteExpiredError;

  /// AppBar title for sell screen
  ///
  /// In en, this message translates to:
  /// **'Sell Bitcoin'**
  String get sellTitle;

  /// Dropdown to choose source wallet
  ///
  /// In en, this message translates to:
  /// **'Select Wallet'**
  String get sellSelectWallet;

  /// Question prompting user to select wallet
  ///
  /// In en, this message translates to:
  /// **'Which wallet do you want to sell from?'**
  String get sellWhichWalletQuestion;

  /// Option for external wallet
  ///
  /// In en, this message translates to:
  /// **'External wallet'**
  String get sellExternalWallet;

  /// Subtitle for external wallet option
  ///
  /// In en, this message translates to:
  /// **'Sell from another Bitcoin wallet'**
  String get sellFromAnotherWallet;

  /// Error message for amount above maximum
  ///
  /// In en, this message translates to:
  /// **'You are trying to sell above the maximum amount that can be sold with this wallet.'**
  String get sellAboveMaxAmountError;

  /// Error message for amount below minimum
  ///
  /// In en, this message translates to:
  /// **'You are trying to sell below the minimum amount that can be sold with this wallet.'**
  String get sellBelowMinAmountError;

  /// Error message for insufficient balance
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance in the selected wallet to complete this sell order.'**
  String get sellInsufficientBalanceError;

  /// Error message for unauthenticated user
  ///
  /// In en, this message translates to:
  /// **'You are not authenticated. Please log in to continue.'**
  String get sellUnauthenticatedError;

  /// Error message for order not found
  ///
  /// In en, this message translates to:
  /// **'The sell order was not found. Please try again.'**
  String get sellOrderNotFoundError;

  /// Error message for already confirmed order
  ///
  /// In en, this message translates to:
  /// **'This sell order has already been confirmed.'**
  String get sellOrderAlreadyConfirmedError;

  /// Screen title for network selection
  ///
  /// In en, this message translates to:
  /// **'Select Network'**
  String get sellSelectNetwork;

  /// Question for payment method selection
  ///
  /// In en, this message translates to:
  /// **'How do you want to pay this invoice?'**
  String get sellHowToPayInvoice;

  /// Option for Bitcoin on-chain payment
  ///
  /// In en, this message translates to:
  /// **'Bitcoin on-chain'**
  String get sellBitcoinOnChain;

  /// Option for Lightning Network payment
  ///
  /// In en, this message translates to:
  /// **'Lightning Network'**
  String get sellLightningNetwork;

  /// Option for Liquid Network payment
  ///
  /// In en, this message translates to:
  /// **'Liquid Network'**
  String get sellLiquidNetwork;

  /// Screen title for payment confirmation
  ///
  /// In en, this message translates to:
  /// **'Confirm payment'**
  String get sellConfirmPayment;

  /// Text before countdown timer for price refresh
  ///
  /// In en, this message translates to:
  /// **'Price will refresh in '**
  String get sellPriceWillRefreshIn;

  /// Label for order number
  ///
  /// In en, this message translates to:
  /// **'Order number'**
  String get sellOrderNumber;

  /// Label for payout recipient
  ///
  /// In en, this message translates to:
  /// **'Payout recipient'**
  String get sellPayoutRecipient;

  /// Display text for CAD balance payout method
  ///
  /// In en, this message translates to:
  /// **'CAD Balance'**
  String get sellCadBalance;

  /// Display text for CRC balance payout method
  ///
  /// In en, this message translates to:
  /// **'CRC Balance'**
  String get sellCrcBalance;

  /// Display text for EUR balance payout method
  ///
  /// In en, this message translates to:
  /// **'EUR Balance'**
  String get sellEurBalance;

  /// Display text for USD balance payout method
  ///
  /// In en, this message translates to:
  /// **'USD Balance'**
  String get sellUsdBalance;

  /// Display text for MXN balance payout method
  ///
  /// In en, this message translates to:
  /// **'MXN Balance'**
  String get sellMxnBalance;

  /// Display text for ARS balance payout method
  ///
  /// In en, this message translates to:
  /// **'ARS Balance'**
  String get sellArsBalance;

  /// Display text for COP balance payout method
  ///
  /// In en, this message translates to:
  /// **'COP Balance'**
  String get sellCopBalance;

  /// Label for amount user pays in
  ///
  /// In en, this message translates to:
  /// **'Payin amount'**
  String get sellPayinAmount;

  /// Label for amount user receives
  ///
  /// In en, this message translates to:
  /// **'Payout amount'**
  String get sellPayoutAmount;

  /// Label for exchange rate
  ///
  /// In en, this message translates to:
  /// **'Exchange rate'**
  String get sellExchangeRate;

  /// Label for wallet used for payment
  ///
  /// In en, this message translates to:
  /// **'Pay from wallet'**
  String get sellPayFromWallet;

  /// Display text for instant payment wallet
  ///
  /// In en, this message translates to:
  /// **'Instant payments'**
  String get sellInstantPayments;

  /// Display text for secure Bitcoin wallet
  ///
  /// In en, this message translates to:
  /// **'Secure Bitcoin wallet'**
  String get sellSecureBitcoinWallet;

  /// Label for fee priority selection
  ///
  /// In en, this message translates to:
  /// **'Fee Priority'**
  String get sellFeePriority;

  /// Display text for fastest fee option
  ///
  /// In en, this message translates to:
  /// **'Fastest'**
  String get sellFastest;

  /// Button for advanced settings
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings'**
  String get sellAdvancedSettings;

  /// Title for advanced options bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Advanced options'**
  String get sellAdvancedOptions;

  /// Label for RBF toggle
  ///
  /// In en, this message translates to:
  /// **'Replace-by-fee activated'**
  String get sellReplaceByFeeActivated;

  /// Option to manually select UTXOs
  ///
  /// In en, this message translates to:
  /// **'Select coins manually'**
  String get sellSelectCoinsManually;

  /// Button to close bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get sellDone;

  /// Title for receive payment screen
  ///
  /// In en, this message translates to:
  /// **'Please pay this invoice'**
  String get sellPleasePayInvoice;

  /// Label for Bitcoin amount
  ///
  /// In en, this message translates to:
  /// **'Bitcoin amount'**
  String get sellBitcoinAmount;

  /// Button to copy invoice
  ///
  /// In en, this message translates to:
  /// **'Copy invoice'**
  String get sellCopyInvoice;

  /// Button to show QR code
  ///
  /// In en, this message translates to:
  /// **'Show QR code'**
  String get sellShowQrCode;

  /// Title for QR code bottom sheet
  ///
  /// In en, this message translates to:
  /// **'QR Code'**
  String get sellQrCode;

  /// Message when no invoice data available
  ///
  /// In en, this message translates to:
  /// **'No invoice data available'**
  String get sellNoInvoiceData;

  /// Message for sell in progress
  ///
  /// In en, this message translates to:
  /// **'Sell in progress…'**
  String get sellInProgress;

  /// Button to go to home screen
  ///
  /// In en, this message translates to:
  /// **'Go home'**
  String get sellGoHome;

  /// Success message for completed order
  ///
  /// In en, this message translates to:
  /// **'Order completed!'**
  String get sellOrderCompleted;

  /// Information about balance crediting
  ///
  /// In en, this message translates to:
  /// **'Your account balance will be credited after your transaction receives 1 confirmation onchain.'**
  String get sellBalanceWillBeCredited;

  /// Success message with the amount sold and the fiat amount received
  ///
  /// In en, this message translates to:
  /// **'You sold {amount} for {fiatAmount}'**
  String sellYouSold(String amount, String fiatAmount);

  /// Screen title for pay feature
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get payTitle;

  /// Label for the optional payment description input in the pay flow
  ///
  /// In en, this message translates to:
  /// **'Payment description (optional)'**
  String get payDescriptionLabel;

  /// Hint text for the optional payment description input in the pay flow
  ///
  /// In en, this message translates to:
  /// **'Add a note for this payment'**
  String get payDescriptionHint;

  /// Label for the payment description on the pay confirmation screen
  ///
  /// In en, this message translates to:
  /// **'Payment description'**
  String get payPaymentDescription;

  /// Label for recipient type
  ///
  /// In en, this message translates to:
  /// **'Recipient type'**
  String get payRecipientType;

  /// Label for recipient name
  ///
  /// In en, this message translates to:
  /// **'Recipient name'**
  String get payRecipientName;

  /// Label for recipient details
  ///
  /// In en, this message translates to:
  /// **'Recipient details'**
  String get payRecipientDetails;

  /// Message when recipient details not available
  ///
  /// In en, this message translates to:
  /// **'No details available'**
  String get payNoDetailsAvailable;

  /// Label for wallet selection dropdown in payment
  ///
  /// In en, this message translates to:
  /// **'Select Wallet'**
  String get paySelectWallet;

  /// Option for external wallet
  ///
  /// In en, this message translates to:
  /// **'External wallet'**
  String get payExternalWallet;

  /// Error message for amount above maximum
  ///
  /// In en, this message translates to:
  /// **'The maximum you can pay with this wallet is {amount}.'**
  String payAboveMaxAmountError(String amount);

  /// Error message for amount below minimum
  ///
  /// In en, this message translates to:
  /// **'The minimum you can pay with this wallet is {amount}.'**
  String payBelowMinAmountError(String amount);

  /// Error message for insufficient balance
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance in the selected wallet to complete this pay order.'**
  String get payInsufficientBalanceError;

  /// Error message for unauthenticated user
  ///
  /// In en, this message translates to:
  /// **'You are not authenticated. Please log in to continue.'**
  String get payUnauthenticatedError;

  /// Screen title for network selection
  ///
  /// In en, this message translates to:
  /// **'Select Network'**
  String get paySelectNetwork;

  /// Question for payment method selection
  ///
  /// In en, this message translates to:
  /// **'How do you want to pay this invoice?'**
  String get payHowToPayInvoice;

  /// Option for Lightning Network payment
  ///
  /// In en, this message translates to:
  /// **'Lightning Network'**
  String get payLightningNetwork;

  /// Option for Liquid Network payment
  ///
  /// In en, this message translates to:
  /// **'Liquid Network'**
  String get payLiquidNetwork;

  /// Button text to confirm and execute payment
  ///
  /// In en, this message translates to:
  /// **'Confirm Payment'**
  String get payConfirmPayment;

  /// Label for order number
  ///
  /// In en, this message translates to:
  /// **'Order number'**
  String get payOrderNumber;

  /// Label for amount user pays in
  ///
  /// In en, this message translates to:
  /// **'Payin amount'**
  String get payPayinAmount;

  /// Label for amount user receives
  ///
  /// In en, this message translates to:
  /// **'Payout amount'**
  String get payPayoutAmount;

  /// Label for exchange rate
  ///
  /// In en, this message translates to:
  /// **'Exchange rate'**
  String get payExchangeRate;

  /// Label for wallet used for payment
  ///
  /// In en, this message translates to:
  /// **'Pay from wallet'**
  String get payPayFromWallet;

  /// Display text for instant payment wallet
  ///
  /// In en, this message translates to:
  /// **'Instant payments'**
  String get payInstantPayments;

  /// Display text for secure Bitcoin wallet
  ///
  /// In en, this message translates to:
  /// **'Secure Bitcoin wallet'**
  String get paySecureBitcoinWallet;

  /// Label for fee priority selection
  ///
  /// In en, this message translates to:
  /// **'Fee Priority'**
  String get payFeePriority;

  /// Display text for fastest fee option
  ///
  /// In en, this message translates to:
  /// **'Fastest'**
  String get payFastest;

  /// Label for network fees amount
  ///
  /// In en, this message translates to:
  /// **'Network fees'**
  String get payNetworkFees;

  /// Button for advanced settings
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings'**
  String get payAdvancedSettings;

  /// Title for advanced options bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Advanced options'**
  String get payAdvancedOptions;

  /// Option to manually select UTXOs
  ///
  /// In en, this message translates to:
  /// **'Select coins manually'**
  String get paySelectCoinsManually;

  /// Button to close bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get payDone;

  /// Button to continue to next step
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get payContinue;

  /// Title for receive payment screen
  ///
  /// In en, this message translates to:
  /// **'Please pay this invoice'**
  String get payPleasePayInvoice;

  /// Label for Bitcoin amount
  ///
  /// In en, this message translates to:
  /// **'Bitcoin amount'**
  String get payBitcoinAmount;

  /// Label for Bitcoin exchange rate
  ///
  /// In en, this message translates to:
  /// **'Bitcoin Price'**
  String get payBitcoinPrice;

  /// Button text to copy invoice to clipboard
  ///
  /// In en, this message translates to:
  /// **'Copy Invoice'**
  String get payCopyInvoice;

  /// Button to show QR code
  ///
  /// In en, this message translates to:
  /// **'Show QR code'**
  String get payShowQrCode;

  /// Title for QR code bottom sheet
  ///
  /// In en, this message translates to:
  /// **'QR Code'**
  String get payQrCode;

  /// Message when no invoice data available
  ///
  /// In en, this message translates to:
  /// **'No invoice data available'**
  String get payNoInvoiceData;

  /// Error message for invalid state
  ///
  /// In en, this message translates to:
  /// **'Invalid state'**
  String get payInvalidState;

  /// Button to view order details
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get payViewDetails;

  /// Title for SINPE receipt bottom sheet
  ///
  /// In en, this message translates to:
  /// **'SINPE Receipt'**
  String get paySinpeReceipt;

  /// Title for payment completed screen
  ///
  /// In en, this message translates to:
  /// **'Payment Completed!'**
  String get payCompleted;

  /// Description for payment completed, with the fiat amount and the recipient
  ///
  /// In en, this message translates to:
  /// **'The payment of {fiatAmount} to {recipient} has been completed.'**
  String payCompletedDescriptionDetails(String fiatAmount, String recipient);

  /// Success message for SINPE payment (Spanish, kept as is)
  ///
  /// In en, this message translates to:
  /// **'SINPE ENVIADO!'**
  String get paySinpeEnviado;

  /// Title for SINPE order details screen
  ///
  /// In en, this message translates to:
  /// **'Order Details'**
  String get payOrderDetails;

  /// Label for amount in SINPE order details
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get paySinpeMonto;

  /// Label for order number in SINPE details
  ///
  /// In en, this message translates to:
  /// **'Order number'**
  String get paySinpeNumeroOrden;

  /// Label for reference number in SINPE details
  ///
  /// In en, this message translates to:
  /// **'Reference number'**
  String get paySinpeNumeroComprobante;

  /// Label for beneficiary in SINPE details
  ///
  /// In en, this message translates to:
  /// **'Beneficiary'**
  String get paySinpeBeneficiario;

  /// Label for origin in SINPE details
  ///
  /// In en, this message translates to:
  /// **'Origin'**
  String get paySinpeOrigen;

  /// Placeholder for unavailable information
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get payNotAvailable;

  /// Option for Bitcoin on-chain payment
  ///
  /// In en, this message translates to:
  /// **'Bitcoin on-chain'**
  String get payBitcoinOnchain;

  /// Title for payment in progress screen
  ///
  /// In en, this message translates to:
  /// **'Payment In Progress!'**
  String get payPaymentInProgress;

  /// Description for payment in progress, before the payin transaction is confirmed onchain
  ///
  /// In en, this message translates to:
  /// **'The payment of {fiatAmount} to {recipient} will be sent after your transaction receives 1 confirmation onchain.'**
  String payPaymentInProgressDescriptionDetails(
    String fiatAmount,
    String recipient,
  );

  /// Description for payment in progress, once the payin transaction is confirmed onchain
  ///
  /// In en, this message translates to:
  /// **'Your transaction is confirmed. The payment of {fiatAmount} to {recipient} is being processed.'**
  String payPaymentPayinConfirmedDescriptionDetails(
    String fiatAmount,
    String recipient,
  );

  /// Text before countdown timer
  ///
  /// In en, this message translates to:
  /// **'Price will refresh in '**
  String get payPriceRefreshIn;

  /// Question prompt for wallet selection
  ///
  /// In en, this message translates to:
  /// **'Which wallet do you want to pay from?'**
  String get payWhichWallet;

  /// Description for external wallet option
  ///
  /// In en, this message translates to:
  /// **'Pay from another Bitcoin wallet'**
  String get payExternalWalletDescription;

  /// Label for RBF toggle
  ///
  /// In en, this message translates to:
  /// **'Replace-by-fee activated'**
  String get payRbfActivated;

  /// Button in modal dialog to copy value to clipboard
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyDialogButton;

  /// Button to close the value display modal dialog
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeDialogButton;

  /// Button to start verification process
  ///
  /// In en, this message translates to:
  /// **'Complete KYC'**
  String get sellCompleteKYC;

  /// Field label for network fees
  ///
  /// In en, this message translates to:
  /// **'Network fees'**
  String get sellSendPaymentNetworkFees;

  /// Continue button on sell payment
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get sellSendPaymentContinue;

  /// In-flight status shown next to the sell confirm button while the payment transaction is being prepared, signed and broadcast
  ///
  /// In en, this message translates to:
  /// **'Sending payment…'**
  String get exchangeSendingPayment;

  /// In-flight status shown after the sell payment transaction is broadcast, while waiting for the order to reflect it
  ///
  /// In en, this message translates to:
  /// **'Payment sent, refreshing your order…'**
  String get exchangePaymentSentRefreshingOrder;

  /// Label for Bitcoin price display
  ///
  /// In en, this message translates to:
  /// **'Bitcoin Price'**
  String get sellBitcoinPriceLabel;

  /// Button text to view order details
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get sellViewDetailsButton;

  /// Title shown when KYC verification is pending
  ///
  /// In en, this message translates to:
  /// **'KYC ID Verification Pending'**
  String get sellKycPendingTitle;

  /// Description explaining user must complete KYC before proceeding
  ///
  /// In en, this message translates to:
  /// **'You must complete ID verification first'**
  String get sellKycPendingDescription;

  /// Generic loading message
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get sellLoadingGeneric;

  /// Hint text in viewer detail dialogs
  ///
  /// In en, this message translates to:
  /// **'Tap to copy'**
  String get viewerTapToCopy;

  /// Title shown in the invoice viewer detail dialog
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get invoiceViewerTitle;

  /// Suffix appended to a completed order summary when the payment used payjoin
  ///
  /// In en, this message translates to:
  /// **'via Payjoin'**
  String get payjoinViaPayjoin;

  /// Suffix appended to a completed order summary when the payment did not use payjoin
  ///
  /// In en, this message translates to:
  /// **'via regular send'**
  String get payjoinViaRegularSend;

  /// Sell confirm screen: label of the row showing the exchange deposit address the payin is sent to
  ///
  /// In en, this message translates to:
  /// **'Deposit address'**
  String get sellDepositAddress;

  /// Pay confirm screen: label of the row showing the exchange deposit address the payin is sent to
  ///
  /// In en, this message translates to:
  /// **'Deposit address'**
  String get payDepositAddress;

  /// Sell: error shown when a price-lock refresh returns a different deposit address than the order was created with (possible backend compromise or MITM); the refreshed order is refused
  ///
  /// In en, this message translates to:
  /// **'The deposit address of this order changed unexpectedly. For your security, do not pay this order: go back and create a new one.'**
  String get sellDepositAddressChangedError;

  /// Pay: error shown when a price-lock refresh returns a different deposit address than the order was created with (possible backend compromise or MITM); the refreshed order is refused
  ///
  /// In en, this message translates to:
  /// **'The deposit address of this order changed unexpectedly. For your security, do not pay this order: go back and create a new one.'**
  String get payDepositAddressChangedError;

  /// Generic catch-all shown for any unexpected sell failure. Deliberately does not include the raw reason: this arm previously returned the exception text verbatim to the user (#1895).
  ///
  /// In en, this message translates to:
  /// **'Your sell order could not be completed right now. Please try again or contact support.'**
  String get sellUnexpectedError;

  /// Shown when the built sell payin fee falls under the network relay floor. Actionable: the user must raise the fee. Wording matches the send equivalent.
  ///
  /// In en, this message translates to:
  /// **'Network fee too low. Choose a higher fee.'**
  String get sellErrorFeeBelowRelayFloor;

  /// Shown when the network fee rates cannot be fetched, so no sell payin can be built. Wording matches the send equivalent.
  ///
  /// In en, this message translates to:
  /// **'Network fees could not be loaded. Check your connection and try again.'**
  String get sellErrorFeesUnavailable;

  /// Generic catch-all shown when a pay order fails for a reason the user cannot act on. Must never quote the raw exception: this key exists to replace the leaked reason (#1895).
  ///
  /// In en, this message translates to:
  /// **'Your payment could not be completed right now. Please try again or contact support.'**
  String get payUnexpectedError;

  /// Shown when a built pay payin's fee is under the network relay floor, so no node would accept it. Actionable: the user must raise the fee.
  ///
  /// In en, this message translates to:
  /// **'Network fee too low. Choose a higher fee.'**
  String get payErrorFeeBelowRelayFloor;

  /// Shown when no fee could be resolved for a pay payin, so it cannot be built.
  ///
  /// In en, this message translates to:
  /// **'Network fees could not be loaded. Check your connection and try again.'**
  String get payErrorFeesUnavailable;

  /// Instructions on recipients screen
  ///
  /// In en, this message translates to:
  /// **'Where and how should we send the money?'**
  String get withdrawRecipientsPrompt;

  /// Generic toast message after copying a value to the clipboard
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// Shown on the sell confirmation when the price lock expired before the payment was sent; nothing was paid.
  ///
  /// In en, this message translates to:
  /// **'This price has expired. A new one is being loaded; check it before confirming.'**
  String get sellQuoteExpiredError;

  /// Shown on the sell or pay confirmation after the payin was broadcast, when the exchange reports the order deadline expired before it saw the payment.
  ///
  /// In en, this message translates to:
  /// **'Payment sent. The exchange reports that the payment deadline for this order expired. Keep the transaction ID below and contact support if the order is not updated.'**
  String get exchangePaymentSentPastDeadline;

  /// Button that leaves the sell or pay confirmation once the exchange reports the payment arrived past the order deadline.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get exchangePaymentSentLeave;

  /// Shown on the pay confirmation when the price lock expired before the payment was sent; nothing was paid.
  ///
  /// In en, this message translates to:
  /// **'This price has expired. A new one is being loaded; check it before confirming.'**
  String get payQuoteExpiredError;

  /// EUR Sell payout option matching BBX: credit the user's exchange account balance.
  ///
  /// In en, this message translates to:
  /// **'Add to my account balance'**
  String get sellPayoutBalance;

  /// EUR Sell regular SEPA explanation matching BBX: the bank transfer appears as sent by Leonod.
  ///
  /// In en, this message translates to:
  /// **'Withdrawals appear as sent by Leonod'**
  String get sellPayoutSepaDescription;

  /// Title for the EUR Sell payout selection screen, matching BBX Select recipient.
  ///
  /// In en, this message translates to:
  /// **'Select recipient'**
  String get sellPayoutTitle;

  /// New-feature badge on the EUR Sell Confidential SEPA option. Store the final display form, including locale-specific capitalization; do not uppercase at runtime.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get sellPayoutNewBadge;

  /// Bitcoin wallet spend gate. No timeout releases a payment: a sync must see it, or prove it can no longer confirm. A payment no sync ever sees keeps the wallet blocked, so the text promises no end.
  ///
  /// In en, this message translates to:
  /// **'Spending is unavailable until this wallet is synced and has seen its previous payments on the network. Refresh the wallet or use Scan for missing transactions, then try again.'**
  String get walletSpendAwaitingObservation;

  /// A retained Payjoin proposal cannot proceed; keep reservations and retry the same proposal only.
  ///
  /// In en, this message translates to:
  /// **'This Payjoin payment is paused because the wallet cannot safely continue. Its inputs remain reserved. Refresh the wallet or use Scan for missing transactions, then retry this proposal while it is still valid. If it has expired, check the payment in Transactions before taking further action.'**
  String get sendPayjoinSpendPaused;

  /// Sell and Pay refuse to create the order when the selected wallet belongs to a different chain or environment.
  ///
  /// In en, this message translates to:
  /// **'The selected wallet does not match this order’s network or the app’s current environment. Select a compatible wallet and try again.'**
  String get exchangePayinNetworkMismatch;

  /// Bitcoin spend refused only because another wallet operation, usually a sync, holds the wallet. Retrying shortly works; it says nothing about previous payments.
  ///
  /// In en, this message translates to:
  /// **'The wallet is busy. Try again in a moment.'**
  String get walletSpendBusy;

  /// Broadcast Transaction error when the failure does not show whether the transaction reached the network
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t confirm that your transaction was broadcast. Check a block explorer before trying again.'**
  String get broadcastSignedTxErrorOutcomeUnknown;

  /// Error message when selected UTXOs don't cover the required amount
  ///
  /// In en, this message translates to:
  /// **'Selected utxos does not cover required amount'**
  String get sendSelectedUtxosInsufficient;

  /// Title for manual coin selection bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Select amount'**
  String get selectAmountTitle;

  /// Shows the requested amount to send
  ///
  /// In en, this message translates to:
  /// **'Amount requested: {amount}'**
  String amountRequestedLabel(String amount);

  /// Label for UTXO address in coin selection tile
  ///
  /// In en, this message translates to:
  /// **'Address: '**
  String get addressLabel;

  /// Label for address type (Receive/Change)
  ///
  /// In en, this message translates to:
  /// **'Type: '**
  String get typeLabel;

  /// Keychain filter / badge: receive (external) keychain
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get coinsKeychainReceive;

  /// Keychain filter / badge: change (internal) keychain
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get coinsKeychainChange;

  /// Title of the Limit Order introduction step
  ///
  /// In en, this message translates to:
  /// **'Open a limit order'**
  String get limitOrdersIntroTitle;

  /// Description of how Limit Orders work
  ///
  /// In en, this message translates to:
  /// **'Choose a lower bitcoin price and an amount to buy from your Bull Bitcoin balance.'**
  String get limitOrdersIntroDescription;

  /// Limit Order introduction bullet about the target price
  ///
  /// In en, this message translates to:
  /// **'Your order remains active until the target index price is reached.'**
  String get limitOrdersIntroBulletPrice;

  /// Limit Order introduction bullet about account balance
  ///
  /// In en, this message translates to:
  /// **'The purchase uses the selected fiat balance when the order executes.'**
  String get limitOrdersIntroBulletBalance;

  /// Limit Order introduction bullet about payout
  ///
  /// In en, this message translates to:
  /// **'Bitcoin is sent to the default wallet you select.'**
  String get limitOrdersIntroBulletExecution;

  /// Title of the Limit Order target-price step
  ///
  /// In en, this message translates to:
  /// **'Choose your target price'**
  String get limitOrdersTargetTitle;

  /// Label for the fiat balance used by a Limit Order
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get limitOrdersPaymentMethod;

  /// Label for the current Bitcoin index price
  ///
  /// In en, this message translates to:
  /// **'Current index price'**
  String get limitOrdersCurrentPrice;

  /// Label for the Limit Order discount percentage
  ///
  /// In en, this message translates to:
  /// **'Discount from current price'**
  String get limitOrdersDiscount;

  /// Title of the Limit Order fiat-amount step
  ///
  /// In en, this message translates to:
  /// **'Set the amount'**
  String get limitOrdersAmountTitle;

  /// Available fiat balance
  ///
  /// In en, this message translates to:
  /// **'Available: {amount}'**
  String limitOrdersAvailableBalance(String amount);

  /// Estimated bitcoin amount for a Limit Order
  ///
  /// In en, this message translates to:
  /// **'Estimated bitcoin: {amount}'**
  String limitOrdersEstimatedBitcoin(String amount);

  /// Title of the Limit Order wallet-selection step
  ///
  /// In en, this message translates to:
  /// **'Choose a payout wallet'**
  String get limitOrdersWalletTitle;

  /// Explains the Limit Order payout wallet
  ///
  /// In en, this message translates to:
  /// **'Bitcoin will be sent to this default wallet when the order executes.'**
  String get limitOrdersWalletDescription;

  /// Opens default-wallet settings from Limit Orders
  ///
  /// In en, this message translates to:
  /// **'Manage default wallets'**
  String get limitOrdersManageDefaultWallets;

  /// Bitcoin on-chain Limit Order payout option
  ///
  /// In en, this message translates to:
  /// **'Bitcoin address'**
  String get limitOrdersWalletBitcoin;

  /// Lightning Limit Order payout option
  ///
  /// In en, this message translates to:
  /// **'Lightning address'**
  String get limitOrdersWalletLightning;

  /// Liquid Limit Order payout option
  ///
  /// In en, this message translates to:
  /// **'Liquid address'**
  String get limitOrdersWalletLiquid;

  /// Title of the Limit Order confirmation step
  ///
  /// In en, this message translates to:
  /// **'Confirm limit order'**
  String get limitOrdersConfirmationTitle;

  /// Fiat balance used to fund the order
  ///
  /// In en, this message translates to:
  /// **'{currency} balance'**
  String limitOrdersBalancePayment(String currency);

  /// Terms and spread notice before creating a Limit Order
  ///
  /// In en, this message translates to:
  /// **'By confirming, you agree to the Bull Bitcoin terms. The final buy price includes your account spread.'**
  String get limitOrdersTermsNotice;

  /// Creates the Limit Order
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get limitOrdersConfirm;

  /// Title shown after a Limit Order is created
  ///
  /// In en, this message translates to:
  /// **'Limit order active'**
  String get limitOrdersCreatedTitle;

  /// Success summary after creating a Limit Order
  ///
  /// In en, this message translates to:
  /// **'Your order will buy {amount} when the index price reaches {price}.'**
  String limitOrdersCreatedMessage(String amount, String price);

  /// Returns from Limit Order success to the Exchange dashboard
  ///
  /// In en, this message translates to:
  /// **'Back to Exchange'**
  String get limitOrdersBackToExchange;

  /// Shown for an invalid Limit Order target price
  ///
  /// In en, this message translates to:
  /// **'Choose a target price below the current index price.'**
  String get limitOrderInvalidTargetError;

  /// Shown for an invalid Limit Order fiat amount
  ///
  /// In en, this message translates to:
  /// **'Enter an amount greater than zero and no more than your available balance.'**
  String get limitOrderInvalidAmountError;

  /// Section title for choosing an in-app wallet as the limit-order payout destination
  ///
  /// In en, this message translates to:
  /// **'Your wallets'**
  String get limitOrdersYourWalletsTitle;

  /// Label for the manual lightning-address field in the limit-order destination step
  ///
  /// In en, this message translates to:
  /// **'Lightning address'**
  String get limitOrdersLightningAddressLabel;

  /// Error shown when the entered lightning destination is not a valid lightning address
  ///
  /// In en, this message translates to:
  /// **'Enter a valid lightning address, not an invoice'**
  String get limitOrdersLightningAddressError;

  /// Buy-limit error when a limit order amount is below the on-chain minimum; {amount} is the minimum in BTC
  ///
  /// In en, this message translates to:
  /// **'Amount is below the on-chain minimum of {amount}'**
  String limitOrdersAmountBelowOnchainMin(String amount);

  /// Buy-limit error when a limit order amount is below the Liquid minimum; {amount} is the minimum in BTC
  ///
  /// In en, this message translates to:
  /// **'Amount is below the Liquid minimum of {amount}'**
  String limitOrdersAmountBelowLiquidMin(String amount);

  /// Buy-limit error when a limit order amount is above the Lightning maximum; {amount} is the maximum in BTC
  ///
  /// In en, this message translates to:
  /// **'Amount is above the Lightning maximum of {amount}'**
  String limitOrdersAmountAboveLightningMax(String amount);

  /// Opens the created Limit Order details from the success screen
  ///
  /// In en, this message translates to:
  /// **'View order details'**
  String get limitOrdersViewOrder;

  /// Title of the info card shown when the user has no funded balance to create a limit order
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance'**
  String get limitOrdersInsufficientBalance;

  /// Message of the info card shown when the user has no funded balance to create a limit order
  ///
  /// In en, this message translates to:
  /// **'You do not have enough balance to create this order.'**
  String get limitOrdersInsufficientBalanceMessage;

  /// Button that opens the fund exchange flow when the user has no balance to create a limit order
  ///
  /// In en, this message translates to:
  /// **'Fund your account'**
  String get limitOrdersFundAccount;

  /// The Bull Bitcoin brand name displayed on exchange screens
  ///
  /// In en, this message translates to:
  /// **'BULL BITCOIN'**
  String get exchangeBrandName;

  /// Subtitle text on the exchange landing screen encouraging users to connect
  ///
  /// In en, this message translates to:
  /// **'Connect your Bull Bitcoin exchange account'**
  String get exchangeLandingConnectAccount;

  /// Subtitle on landing screen v2 describing Bull Bitcoin as recommended
  ///
  /// In en, this message translates to:
  /// **'Recommended Bitcoin Exchange'**
  String get exchangeLandingRecommendedExchange;

  /// Feature bullet point describing self-custody Bitcoin purchases
  ///
  /// In en, this message translates to:
  /// **'• Buy Bitcoin straight to self-custody'**
  String get exchangeFeatureSelfCustody;

  /// Feature bullet point describing DCA and automated buying features
  ///
  /// In en, this message translates to:
  /// **'• DCA, Limit orders and Auto-buy'**
  String get exchangeFeatureDcaOrders;

  /// Feature bullet point describing selling Bitcoin functionality
  ///
  /// In en, this message translates to:
  /// **'• Sell Bitcoin, get paid with Bitcoin'**
  String get exchangeFeatureSellBitcoin;

  /// Feature bullet point describing bank transfer and bill payment features
  ///
  /// In en, this message translates to:
  /// **'• Send bank transfers and pay bills'**
  String get exchangeFeatureBankTransfers;

  /// Feature bullet point describing customer support chat feature
  ///
  /// In en, this message translates to:
  /// **'• Chat with customer support'**
  String get exchangeFeatureCustomerSupport;

  /// Feature bullet point describing unified transaction history feature
  ///
  /// In en, this message translates to:
  /// **'• Unified transaction history'**
  String get exchangeFeatureUnifiedHistory;

  /// Legal disclaimer about exchange service availability and KYC requirements
  ///
  /// In en, this message translates to:
  /// **'Access to exchange services will be restricted to countries where Bull Bitcoin can legally operate and may require KYC.'**
  String get exchangeLandingDisclaimerLegal;

  /// Disclaimer informing users that exchange services are not available in the mobile app
  ///
  /// In en, this message translates to:
  /// **'Cryptocurrency exchange services are not available in the Bull Bitcoin mobile application.'**
  String get exchangeLandingDisclaimerNotAvailable;

  /// Button label for logging in or signing up to the exchange
  ///
  /// In en, this message translates to:
  /// **'Login Or Sign up'**
  String get exchangeLoginButton;

  /// Button label for navigating to the Bull Bitcoin exchange website
  ///
  /// In en, this message translates to:
  /// **'Go to Bull Bitcoin exchange website'**
  String get exchangeGoToWebsiteButton;
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
