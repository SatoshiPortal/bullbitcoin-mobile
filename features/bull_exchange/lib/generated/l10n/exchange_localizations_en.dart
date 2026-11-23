// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'exchange_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class ExchangeLocalizationsEn extends ExchangeLocalizations {
  ExchangeLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get exchangeAccountInfoEmailLabel => 'Email';

  @override
  String get exchangeAccountInfoFirstNameLabel => 'First name';

  @override
  String get exchangeAccountInfoLastNameLabel => 'Last name';

  @override
  String get exchangeAccountInfoLoadErrorMessage =>
      'Unable to load account information';

  @override
  String get exchangeAccountInfoTitle => 'Account information';

  @override
  String get exchangeAccountInfoUserNumberCopiedMessage =>
      'User number copied to clipboard';

  @override
  String get exchangeAccountInfoUserNumberLabel => 'User number';

  @override
  String get exchangeAccountInfoVerificationIdentityVerified =>
      'Identity verified';

  @override
  String get exchangeAccountInfoVerificationLevelLabel => 'Verification level';

  @override
  String get exchangeAccountInfoVerificationLightVerification =>
      'Light verification';

  @override
  String get exchangeAccountInfoVerificationLimitedVerification =>
      'Limited verification';

  @override
  String get exchangeAccountInfoVerificationNotVerified => 'Not verified';

  @override
  String get exchangeAppSettingsDefaultCurrencyLabel => 'Default Currency';

  @override
  String get exchangeAppSettingsEmailNotificationsDescription =>
      'Receive email notifications for orders and account updates';

  @override
  String get exchangeAppSettingsEmailNotificationsLabel =>
      'Email Notifications';

  @override
  String get exchangeAppSettingsPreferredLanguageLabel => 'Preferred Language';

  @override
  String get exchangeAppSettingsSaveButton => 'Save';

  @override
  String get exchangeAppSettingsSaveSuccessMessage =>
      'Settings saved successfully';

  @override
  String get exchangeAppSettingsValidationWarning =>
      'Please set both language and currency preferences before saving.';

  @override
  String get exchangeAuthErrorMessage =>
      'An error occurred, please try logging in again.';

  @override
  String get exchangeBitcoinWalletsTitle => 'Default Bitcoin Wallets';

  @override
  String get exchangeErrorNetwork =>
      'Check your internet connection and try again.';

  @override
  String get exchangeErrorSavingPreferences =>
      'Your preferences could not be saved. Please try again.';

  @override
  String get exchangeFileUploadButton => 'Upload';

  @override
  String get exchangeFileUploadDocumentTitle => 'Upload any document';

  @override
  String get exchangeFileUploadInstructions =>
      'If you need to send any other documents, upload them here.';

  @override
  String get exchangeFileUploadStatusAccepted => 'Accepted';

  @override
  String get exchangeFileUploadStatusInReview => 'In Review';

  @override
  String get exchangeFileUploadStatusRejectedBadge => 'Rejected';

  @override
  String get exchangeFileUploadSuccess => 'File uploaded successfully';

  @override
  String get exchangeFileUploadTapToReupload => 'Tap to re-upload';

  @override
  String get exchangeFileUploadTitle => 'Secure File Upload';

  @override
  String get exchangeReferralsApplyToJoinMessage =>
      'Apply to join the program here';

  @override
  String get exchangeReferralsContactSupportMessage =>
      'Contact support to learn about our referral program';

  @override
  String get exchangeReferralsJoinMissionTitle => 'Join the mission';

  @override
  String get exchangeReferralsMissionLink => 'bullbitcoin.com/mission';

  @override
  String get exchangeReferralsTitle => 'Referral Codes';

  @override
  String get exchangeSecurityAccessSettingsButton => 'Access Settings';

  @override
  String get exchangeSecurityManage2FAPasswordLabel =>
      'Manage 2FA and password';

  @override
  String get exchangeSettingsAccountInformationTitle => 'Account Information';

  @override
  String get exchangeSettingsErrorDocumentAlreadySubmitted =>
      'A document has already been submitted.';

  @override
  String get exchangeSettingsErrorDocumentEmpty =>
      'That file is empty. Choose another one.';

  @override
  String get exchangeSettingsErrorDocumentTooLarge =>
      'That file is too large. Choose a smaller one.';

  @override
  String get exchangeSettingsErrorDocumentTypeNotAllowed =>
      'That file type is not accepted. Choose another one.';

  @override
  String get exchangeSettingsErrorDocumentUnreadable =>
      'That file could not be read. Choose another one.';

  @override
  String get exchangeSettingsErrorLoadingAccount =>
      'Your account details could not be loaded. Please try again.';

  @override
  String get exchangeSettingsErrorLoadingStatistics =>
      'Your trading statistics could not be loaded. Please try again.';

  @override
  String get exchangeSettingsErrorLoadingUploadStatus =>
      'Your upload status could not be loaded. Please try again.';

  @override
  String get exchangeSettingsErrorUploadingDocument =>
      'The document could not be uploaded. Please try again.';

  @override
  String get exchangeSettingsLogInTitle => 'Log In';

  @override
  String get exchangeSettingsRecipientsTitle => 'Recipients';

  @override
  String get exchangeSettingsReferralsTitle => 'Referrals';

  @override
  String get exchangeSettingsSecuritySettingsTitle => 'Security Settings';

  @override
  String get exchangeSettingsTransactionsTitle => 'Transactions';

  @override
  String exchangeStatisticsAsOf(String date) {
    return 'As of $date';
  }

  @override
  String get exchangeStatisticsAveragePrice => 'Average Price';

  @override
  String get exchangeStatisticsBillerStats => 'Biller Statistics';

  @override
  String get exchangeStatisticsBuyAvgPriceDesc =>
      'Average price paid per bitcoin when buying';

  @override
  String get exchangeStatisticsBuySellRatio => 'Buy/Sell Ratio';

  @override
  String get exchangeStatisticsBuySellRatioDesc =>
      'Percentage of total volume from buying vs selling';

  @override
  String get exchangeStatisticsBuyStats => 'Buy Statistics';

  @override
  String get exchangeStatisticsBuyTradeCountDesc =>
      'Number of bitcoin purchase transactions';

  @override
  String get exchangeStatisticsBuyVolumeDesc =>
      'Total amount spent buying bitcoin';

  @override
  String exchangeStatisticsCurrency(String currency) {
    return 'Currency: $currency';
  }

  @override
  String get exchangeStatisticsNoData => 'No statistics available';

  @override
  String get exchangeStatisticsOrderStats => 'Order Statistics';

  @override
  String get exchangeStatisticsSellAvgPriceDesc =>
      'Average price received per bitcoin when selling';

  @override
  String get exchangeStatisticsSellStats => 'Sell Statistics';

  @override
  String get exchangeStatisticsSellTradeCountDesc =>
      'Number of bitcoin sell transactions';

  @override
  String get exchangeStatisticsSellVolumeDesc =>
      'Total amount received from selling bitcoin';

  @override
  String get exchangeStatisticsTitle => 'Statistics';

  @override
  String get exchangeStatisticsTotalAmount => 'Total Amount';

  @override
  String get exchangeStatisticsTotalVolume => 'Total Trading Volume';

  @override
  String get exchangeStatisticsTotalVolumeDesc =>
      'Combined buy and sell volumes in fiat currencies';

  @override
  String get exchangeStatisticsTradeCount => 'Trade Count';

  @override
  String exchangeStatisticsTradeCountByCurrency(int count, String currency) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trades ($currency)',
      one: '1 trade ($currency)',
    );
    return '$_temp0';
  }

  @override
  String exchangeStatisticsTradeCountValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trades',
      one: '1 trade',
    );
    return '$_temp0';
  }

  @override
  String get exchangeStatisticsVolume => 'Volume';

  @override
  String get exchangeSupportChatAttachFileTooltip => 'Attach a file';

  @override
  String get exchangeSupportChatAttachLogsFailed =>
      'Failed to attach logs. Please try again.';

  @override
  String get exchangeSupportChatAttachLogsTooltip => 'Attach logs';

  @override
  String get exchangeSupportChatAttachmentImage => 'Image';

  @override
  String get exchangeSupportChatAttachmentUnknownFile => 'Unknown file';

  @override
  String get exchangeSupportChatEmptyState =>
      'No messages yet. Start a conversation!';

  @override
  String get exchangeSupportChatFetchFileDataFailed =>
      'Failed to fetch file data';

  @override
  String get exchangeSupportChatInputHint => 'Type a message…';

  @override
  String get exchangeSupportChatLoadAttachmentError =>
      'Couldn\'t open the attachment. Please try again.';

  @override
  String get exchangeSupportChatLoadMessagesError =>
      'Couldn\'t load messages. Please try again.';

  @override
  String get exchangeSupportChatMessageEmptyError => 'Message cannot be empty';

  @override
  String get exchangeSupportChatMessageRequired => 'A message is required';

  @override
  String get exchangeSupportChatPickFilesFailed =>
      'Failed to pick files. Please try again.';

  @override
  String get exchangeSupportChatSendMessageError =>
      'Couldn\'t send your message. Please try again.';

  @override
  String get exchangeSupportChatSendTooltip => 'Send message';

  @override
  String get exchangeSupportChatTitle => 'Support Chat';

  @override
  String get exchangeSupportChatYesterday => 'Yesterday';

  @override
  String get exchangeSupportLoginChatRequired =>
      'To get human support, you must first log in to your Bull Bitcoin account. It\'s 100% free and no KYC is required, only an email address.';

  @override
  String get loginButton => 'LOGIN';

  @override
  String get notLoggedInTitle => 'You Are Not Logged in';

  @override
  String get oopsSomethingWentWrong => 'Oops! Something went wrong';

  @override
  String get retry => 'Retry';

  @override
  String get settingsAppSettingsTitle => 'App Settings';

  @override
  String get exchangeSupportChatLogDraft => 'Here are my logs';

  @override
  String get settingsAccountSettingsTitle => 'Account Settings';

  @override
  String get settingsErrorSavingSetting =>
      'That setting could not be saved. Please try again.';

  @override
  String get exchangeAccessSettingsTitle => 'BULL Exchange';

  @override
  String get exchangeAccessSettingsLabel => 'Exchange features';

  @override
  String get exchangeAccessSettingsDescription =>
      'Show Buy, Sell and Pay on the home screen. Swap remains available.';

  @override
  String get exchangeAccessSettingsOffHint =>
      'Enable to sign in or create a Bull Bitcoin account.';

  @override
  String get exchangeAccessSettingsOnHint => 'Exchange features are enabled.';

  @override
  String get exchangeAccessSignIn => 'Sign in or create an account';

  @override
  String get exchangeAccessDisableTitle => 'Disable exchange features?';

  @override
  String get exchangeAccessDisableBody =>
      'This signs you out on this device. Existing orders, AutoBuy and recurring buys are not cancelled.';

  @override
  String get exchangeAccessDisableConfirm => 'Sign out and disable';

  @override
  String get exchangeTradingRetry => 'Retry';

  @override
  String get exchangeAccessUnreadable =>
      'Exchange access could not be read. Retry or reset it.';

  @override
  String get exchangeAccessReset => 'Reset exchange access';

  @override
  String get exchangeAccessLogoutIncomplete =>
      'Sign out is incomplete. Finish signing out before enabling exchange.';

  @override
  String get exchangeAccessRetryLogout => 'Finish signing out';
}
