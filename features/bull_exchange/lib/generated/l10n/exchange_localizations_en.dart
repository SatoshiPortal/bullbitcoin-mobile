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

  @override
  String get fundExchangeTitle => 'Funding';

  @override
  String get fundExchangeAccountTitle => 'Fund your account';

  @override
  String get fundExchangeAccountSubtitle =>
      'Select your country and payment method';

  @override
  String get fundExchangeRestrictedTitle => 'Funding unavailable';

  @override
  String get fundExchangeRestrictedMessage =>
      'Funding is not available on your account. Please contact support for more information.';

  @override
  String get fundExchangeWarningTitle => 'Watch out for scammers';

  @override
  String get fundExchangeWarningDescription =>
      'If someone is asking you to buy Bitcoin or \"helping you\", be careful, they may be trying to scam you!';

  @override
  String get fundExchangeWarningTacticsTitle => 'Common scammer tactics';

  @override
  String get fundExchangeWarningTactic1 =>
      'They are promising returns on investment';

  @override
  String get fundExchangeWarningTactic2 => 'They are offering you a loan';

  @override
  String get fundExchangeWarningTactic3 =>
      'They say they work for debt or tax collection';

  @override
  String get fundExchangeWarningTactic4 =>
      'They ask to send Bitcoin to their address';

  @override
  String get fundExchangeWarningTactic5 =>
      'They ask to send Bitcoin on another platform';

  @override
  String get fundExchangeWarningTactic6 => 'They want you to share your screen';

  @override
  String get fundExchangeWarningTactic7 =>
      'They tell you not to worry about this warning';

  @override
  String get fundExchangeWarningTactic8 =>
      'They are pressuring you to act quickly';

  @override
  String get fundExchangeWarningConfirmation =>
      'I confirm that I am not being asked to buy Bitcoin by someone else.';

  @override
  String get fundExchangeContinueButton => 'Continue';

  @override
  String get fundExchangeScamConsentError =>
      'Failed to register your consent. Please try again.';

  @override
  String get fundExchangeDoneButton => 'Done';

  @override
  String get fundExchangeJurisdictionCanada => '🇨🇦 Canada';

  @override
  String get fundExchangeJurisdictionEurope => '🇪🇺 Europe (SEPA)';

  @override
  String get fundExchangeJurisdictionMexico => '🇲🇽 Mexico';

  @override
  String get fundExchangeJurisdictionCostaRica => '🇨🇷 Costa Rica';

  @override
  String get fundExchangeJurisdictionArgentina => '🇦🇷 Argentina';

  @override
  String get fundExchangeJurisdictionColombia => '🇨🇴 Colombia';

  @override
  String get fundExchangeMethodEmailETransfer => 'Email E-Transfer';

  @override
  String get fundExchangeMethodEmailETransferSubtitle =>
      'Easiest and fastest method (instant)';

  @override
  String get fundExchangeMethodBankTransferWire =>
      'Bank Transfer (Wire or EFT)';

  @override
  String get fundExchangeMethodBankTransferWireSubtitle =>
      'Best and most reliable option for larger amounts (same or next day)';

  @override
  String get fundExchangeMethodOnlineBillPayment => 'Online Bill Payment';

  @override
  String get fundExchangeMethodOnlineBillPaymentSubtitle =>
      'Slowest option, but can be done via online banking (3-4 business days)';

  @override
  String get fundExchangeMethodCanadaPost =>
      'In-person cash or debit at Canada Post';

  @override
  String get fundExchangeMethodCanadaPostSubtitle =>
      'Best for those who prefer to pay in person';

  @override
  String get fundExchangeMethodInstantSepa => 'Instant & Regular SEPA';

  @override
  String get fundExchangeMethodInstantSepaSubtitle =>
      'Fastest - Only for transactions below €30,000';

  @override
  String get fundExchangeMethodRegularSepa => 'Regular SEPA';

  @override
  String get fundExchangeMethodRegularSepaSubtitle =>
      'Only use for larger transactions above €30,000';

  @override
  String get fundExchangeBankTransferWireTitle => 'Bank transfer (wire)';

  @override
  String get fundExchangeBankTransferWireDescription =>
      'Send a wire transfer from your bank account using Bull Bitcoin\'s bank details below. Your bank may require only some parts of these details.';

  @override
  String get fundExchangeBankTransferWireTimeframe =>
      'Any funds you send will be added to your Bull Bitcoin within 1-2 business days.';

  @override
  String get fundExchangeLabelBeneficiaryName => 'Beneficiary name';

  @override
  String get fundExchangeHelpBeneficiaryName =>
      'Use our official corporate name. Do not use \"Bull Bitcoin\".';

  @override
  String get fundExchangeLabelTransferCode =>
      'Transfer code (add this as payment description)';

  @override
  String get fundExchangeHelpTransferCode =>
      'Add this as the reason for the transfer';

  @override
  String get fundExchangeInfoTransferCode =>
      'You must add the transfer code as the \"message\" or \"reason\" when making the payment.';

  @override
  String get fundExchangeLabelBankAccountDetails => 'Bank account details';

  @override
  String get fundExchangeLabelSwiftCode => 'SWIFT code';

  @override
  String get fundExchangeLabelInstitutionNumber => 'Institution number';

  @override
  String get fundExchangeLabelTransitNumber => 'Transit number';

  @override
  String get fundExchangeLabelRoutingNumber => 'Routing number';

  @override
  String get fundExchangeLabelBeneficiaryAddress => 'Beneficiary address';

  @override
  String get fundExchangeLabelBankName => 'Bank name';

  @override
  String get fundExchangeLabelBankAddress => 'Address of our bank';

  @override
  String get fundExchangeETransferTitle => 'E-Transfer details';

  @override
  String get fundExchangeETransferDescription =>
      'Any amount you send from your bank via Email E-Transfer using the information below will be credited to your Bull Bitcoin account balance within a few minutes.';

  @override
  String get fundExchangeETransferLabelBeneficiaryName =>
      'Use this as the E-transfer beneficiary name';

  @override
  String get fundExchangeETransferLabelEmail =>
      'Send the E-transfer to this email';

  @override
  String get fundExchangeETransferLabelSecretQuestion => 'Secret question';

  @override
  String get fundExchangeETransferLabelSecretAnswer => 'Secret answer';

  @override
  String get fundExchangeOnlineBillPaymentTitle => 'Online Bill Payment';

  @override
  String get fundExchangeOnlineBillPaymentDescription =>
      'Any amount you send via your bank\'s online bill payment feature using the information below will be credited to your Bull Bitcoin account balance within 3-4 business days.';

  @override
  String get fundExchangeOnlineBillPaymentLabelBillerName =>
      'Search your bank\'s list of billers for this name';

  @override
  String get fundExchangeOnlineBillPaymentHelpBillerName =>
      'Add this company as a payee - it\'s Bull Bitcoin\'s payment processor';

  @override
  String get fundExchangeCanadaPostTitle =>
      'In-person cash or debit at Canada Post';

  @override
  String get fundExchangeCanadaPostStep1 => '1. Go to any Canada Post location';

  @override
  String get fundExchangeCanadaPostStep2 =>
      '2. Ask the cashier to scan the \"Loadhub\" QR code';

  @override
  String get fundExchangeCanadaPostStep3 =>
      '3. Tell the cashier the amount you want to load';

  @override
  String get fundExchangeCanadaPostStep4 =>
      '4. The cashier will ask to see a piece of government-issued ID and verify that the name on your ID matches your Bull Bitcoin account';

  @override
  String get fundExchangeCanadaPostStep5 => '5. Pay with cash or debit card';

  @override
  String get fundExchangeCanadaPostStep6 =>
      '6. The cashier will hand you a receipt, keep it as your proof of payment';

  @override
  String get fundExchangeCanadaPostStep7 =>
      '7. The funds will be added to your Bull Bitcoin account balance within 30 minutes';

  @override
  String get fundExchangeCanadaPostQrCodeLabel => 'Loadhub QR code';

  @override
  String get fundExchangeSepaTitle => 'SEPA transfer';

  @override
  String get fundExchangeSepaDescription =>
      'Send a SEPA transfer from your bank account using the details below ';

  @override
  String get fundExchangeSepaDescriptionExactly => 'exactly.';

  @override
  String get fundExchangeInstantSepaInfo =>
      'Only use for transactions below €20,000. For larger transactions, use the Regular SEPA option.';

  @override
  String get fundExchangeRegularSepaInfo =>
      'Only use for transactions above €20,000. For smaller transactions, use the Instant SEPA option.';

  @override
  String get fundExchangeLabelIban => 'IBAN account number';

  @override
  String get fundExchangeLabelBicCode => 'BIC code';

  @override
  String get fundExchangeLabelBankAccountCountry => 'Bank account country';

  @override
  String get fundExchangeInfoBankCountryUk =>
      'Our bank country is the United Kingdom.';

  @override
  String get fundExchangeInfoBeneficiaryNameLeonod =>
      'The name of the beneficiary should be LEONOD. If you put anything else, your payment will be rejected.';

  @override
  String get fundExchangeInfoPaymentDescription =>
      'In the payment description, add your transfer code.';

  @override
  String get fundExchangeHelpBeneficiaryAddress =>
      'Our official address, in case this is required by your bank';

  @override
  String get fundExchangeLabelRecipientName => 'Recipient name';

  @override
  String get fundExchangeLabelBankCountry => 'Bank country';

  @override
  String get fundExchangeLabelRecipientAddress => 'Recipient address';

  @override
  String get fundExchangeSpeiTitle => 'SPEI transfer';

  @override
  String get fundExchangeSpeiDescription => 'Transfer funds using your CLABE';

  @override
  String get fundExchangeSpeiInfo =>
      'Make a deposit using SPEI transfer (instant).';

  @override
  String get fundExchangeLabelClabe => 'CLABE';

  @override
  String get fundExchangeLabelMemo => 'Memo';

  @override
  String get fundExchangeSinpeTitle => 'SINPE Transfer';

  @override
  String get fundExchangeSinpeDescription => 'Transfer Colones using SINPE';

  @override
  String get fundExchangeCrIbanCrcTitle => 'Bank Transfer (CRC)';

  @override
  String get fundExchangeCrIbanUsdTitle => 'Bank Transfer (USD)';

  @override
  String get fundExchangeArsBankTransferTitle => 'Bank Transfer';

  @override
  String get fundExchangeArsBankTransferDescription =>
      'Send a bank transfer from your bank account using the exact Argentina bank details below.';

  @override
  String get fundExchangeLabelRecipientNameArs => 'Recipient Name';

  @override
  String get fundExchangeLabelCvu => 'CVU';

  @override
  String get fundExchangeErrorLoadingDetails =>
      'The payment details could not be loaded at this moment. Please go back and try again, pick another payment method or come back later.';

  @override
  String get fundExchangeErrorTitleOrdPo404 => 'Payment Option Unavailable';

  @override
  String get fundExchangeErrorOrdPo404 => 'No payment option available';

  @override
  String get fundExchangeErrorTitleRcpPo404 => 'Payment Option Not Available';

  @override
  String get fundExchangeErrorRcpPo404 =>
      'You do not have the required permissions to access this funding option. Either your KYC is insufficient or this option is not available for your account';

  @override
  String get fundExchangeErrorTitleRcpPosinpe404 => 'SINPE Not Available';

  @override
  String get fundExchangeErrorRcpPosinpe404 =>
      'To access this funding option, your phone number must be registered with the SINPE network in Costa Rica.';

  @override
  String get fundExchangeErrorTitleOrdKyc400 => 'KYC Requirements Missing';

  @override
  String get fundExchangeErrorOrdKyc400 =>
      'You do not have the KYC requirements for this action';

  @override
  String get fundExchangeErrorTitleOrdCop400 => 'Invalid COP Funding Data';

  @override
  String get fundExchangeErrorOrdCop400 =>
      'Invalid request data for COP funding';

  @override
  String get fundExchangeErrorOpeningPaymentLink =>
      'The payment link could not be opened. Please try again.';

  @override
  String get fundExchangeErrorTitleOrdCsrcp400 =>
      'Virtual Payment Not Activated';

  @override
  String get fundExchangeErrorOrdCsrcp400 =>
      'Please activate the virtual payment option for this SEPA recipient';

  @override
  String get fundExchangeErrorTitleRcp400 => 'Invalid Request';

  @override
  String get fundExchangeErrorRcp400 => 'Invalid request';

  @override
  String get fundExchangeErrorFetchingBankCodes =>
      'Error fetching bank codes. Please try again later.';

  @override
  String get fundExchangeSinpeDescriptionBold => 'it will be rejected.';

  @override
  String get fundExchangeSinpeAddedToBalance =>
      'Once the payment is sent, it will be added to your account balance.';

  @override
  String get fundExchangeSinpeLabelPhone => 'Send to this phone number';

  @override
  String get fundExchangeSinpeLabelRecipientName => 'Recipient Name';

  @override
  String get fundExchangeCrIbanCrcDescription =>
      'Send a bank transfer from your bank account using the details below ';

  @override
  String get fundExchangeCrIbanCrcDescriptionBold => 'exactly';

  @override
  String get fundExchangeCrIbanCrcDescriptionEnd =>
      '. Funds will be added to your account balance.';

  @override
  String get fundExchangeCrIbanCrcLabelIban =>
      'IBAN Account Number (Colones only)';

  @override
  String get fundExchangeCrIbanCrcLabelPaymentDescription =>
      'Payment Description';

  @override
  String get fundExchangeCrIbanCrcPaymentDescriptionHelp =>
      'Your transfer code.';

  @override
  String get fundExchangeCrIbanCrcTransferCodeWarning =>
      'You must add the transfer code as \"message\" or \"reason\" or \"description\" when making the payment. If you forget to include this code, your payment may be rejected.';

  @override
  String get fundExchangeCrIbanCrcLabelRecipientName => 'Recipient Name';

  @override
  String get fundExchangeCrIbanCrcRecipientNameHelp =>
      'Use our official corporate name. Do not use \"Bull Bitcoin\".';

  @override
  String get fundExchangeCrIbanCrcLabelCedulaJuridica => 'Cédula Jurídica';

  @override
  String get fundExchangeCrIbanUsdDescription =>
      'Send a bank transfer from your bank account using the details below ';

  @override
  String get fundExchangeCrIbanUsdDescriptionBold => 'exactly';

  @override
  String get fundExchangeCrIbanUsdDescriptionEnd =>
      '. Funds will be added to your account balance.';

  @override
  String get fundExchangeCrIbanUsdLabelIban =>
      'IBAN Account Number (US dollars only)';

  @override
  String get fundExchangeCrIbanUsdLabelPaymentDescription =>
      'Payment Description';

  @override
  String get fundExchangeCrIbanUsdPaymentDescriptionHelp =>
      'Your transfer code.';

  @override
  String get fundExchangeCrIbanUsdTransferCodeWarning =>
      'You must add the transfer code as \"message\" or \"reason\" or \"description\" when making the payment. If you forget to include this code, your payment may be rejected.';

  @override
  String get fundExchangeCrIbanUsdLabelRecipientName => 'Recipient Name';

  @override
  String get fundExchangeCrIbanUsdRecipientNameHelp =>
      'Use our official corporate name. Do not use \"Bull Bitcoin\".';

  @override
  String get fundExchangeCrIbanUsdLabelCedulaJuridica => 'Cédula Jurídica';

  @override
  String get fundExchangeCostaRicaMethodSinpeTitle => 'SINPE Móvil';

  @override
  String get fundExchangeCostaRicaMethodSinpeSubtitle =>
      'Transfer Colones using SINPE';

  @override
  String get fundExchangeCostaRicaMethodIbanCrcTitle => 'IBAN Costa Rica (CRC)';

  @override
  String get fundExchangeCostaRicaMethodIbanCrcSubtitle =>
      'Transfer funds in Costa Rican Colón (CRC)';

  @override
  String get fundExchangeCostaRicaMethodIbanUsdTitle => 'IBAN Costa Rica (USD)';

  @override
  String get fundExchangeCostaRicaMethodIbanUsdSubtitle =>
      'Transfer funds in US Dollars (USD)';

  @override
  String get doneButton => 'Done';

  @override
  String get fundExchangeSpeiTransfer => 'SPEI transfer';

  @override
  String get fundExchangeSpeiSubtitle => 'Transfer funds using your CLABE';

  @override
  String get fundExchangeBankTransfer => 'Bank Transfer';

  @override
  String get fundExchangeBankTransferSubtitle =>
      'Send a bank transfer from your bank account';

  @override
  String get fundExchangeCopDailyLimitWarning =>
      'If you exceed your daily transaction limit, the transaction will fail. You will have to contact customer support.';

  @override
  String get fundExchangeCopSenderName => 'Sender Name';

  @override
  String get fundExchangeCopIssuingBank => 'Issuing Bank';

  @override
  String get fundExchangeCopSelectBankError => 'Please select an issuing bank';

  @override
  String get fundExchangeCopAmount => 'Amount';

  @override
  String get fundExchangeCopEnterAmountError => 'Please enter an amount';

  @override
  String get fundExchangeCopValidAmountError => 'Please enter a valid amount';

  @override
  String get fundExchangeCopGeneratePaymentLink => 'Generate Payment Link';

  @override
  String get fundExchangeCopRedirectMessage =>
      'You will be redirected to an external page to make the payment.';

  @override
  String get fundExchangeCopOpenPaymentLink => 'Open Payment Link';

  @override
  String get fundExchangeErrorNetwork =>
      'Check your internet connection and try again.';

  @override
  String get fundExchangeMethodConfidentialSepa => 'Confidential SEPA';

  @override
  String get fundExchangeMethodConfidentialSepaSubtitle =>
      'A personal virtual IBAN to deposit money privately';

  @override
  String get networkFeatureUnavailable =>
      'This feature is unavailable on the selected network.';

  @override
  String get fundExchangeOnlineBillPaymentLabelAccountNumber =>
      'Add this as the account number';

  @override
  String get fundExchangeOnlineBillPaymentHelpAccountNumber =>
      'This unique account number is created just for you';

  @override
  String get fundExchangeSinpeWarningNoBitcoin => 'Do not put';

  @override
  String get fundExchangeSinpeWarningNoBitcoinDescription =>
      ' the word \"Bitcoin\" or \"Crypto\" in the payment description. This will block your payment.';

  @override
  String get exchangeCurrencyDropdownTitle => 'Select Currency';

  @override
  String get exchangeCurrencyDropdownValidation => 'Please select a currency';

  @override
  String get exchangeAmountInputTitle => 'Enter Amount';

  @override
  String get exchangeAmountInputValidationEmpty => 'Please enter an amount';

  @override
  String get exchangeAmountInputValidationInvalid => 'Invalid amount';

  @override
  String get exchangeAmountInputValidationZero =>
      'Amount must be greater than zero';

  @override
  String get exchangeAmountInputValidationInsufficient =>
      'Insufficient balance';

  @override
  String get exchangeBitcoinWalletsBitcoinAddressLabel => 'Bitcoin Address';

  @override
  String get exchangeBitcoinWalletsLightningAddressLabel =>
      'Lightning (LN address)';

  @override
  String get exchangeBitcoinWalletsLiquidAddressLabel => 'Liquid address';

  @override
  String get exchangeBitcoinWalletsEnterAddressHint => 'Enter address';

  @override
  String get exchangeBitcoinWalletsSaveSuccess =>
      'Wallet address saved successfully';

  @override
  String get exchangeBitcoinWalletsDescription =>
      'Set default wallet addresses for automatic Bitcoin withdrawals.';

  @override
  String get exchangeDcaAddressLabelBitcoin => 'Bitcoin address';

  @override
  String get exchangeDcaAddressLabelLightning => 'Lightning address';

  @override
  String get exchangeDcaAddressLabelLiquid => 'Liquid address';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get exchangeBitcoinWalletsLoadFailed =>
      'Failed to load default wallets';

  @override
  String get exchangeBitcoinWalletsAddressEmpty => 'Address cannot be empty';

  @override
  String get exchangeBitcoinWalletsSaveFailed =>
      'Failed to save wallet address';

  @override
  String get exchangeBitcoinWalletsDeleteFailed =>
      'Failed to delete wallet address';

  @override
  String destinationExpectedType(String type) {
    return 'Enter or scan a valid $type.';
  }

  @override
  String get wizardExchangeTitle => 'BULL Exchange';

  @override
  String get wizardExchangeDescription =>
      'Buy, sell and pay with Bull Bitcoin directly from your wallet.';

  @override
  String get settingsTermsOfServiceTitle => 'Terms of Service';

  @override
  String get continueButton => 'Continue';

  @override
  String get autoBuyTitle => 'Auto-Buy';

  @override
  String get autoBuyDescription =>
      'Automatically buy bitcoin each time you deposit funds into your account';

  @override
  String get autoBuyActivate => 'Activate Auto-Buy';

  @override
  String get autoBuyDeactivate => 'Deactivate Auto-Buy';

  @override
  String get autoBuyCancelTitle => 'Cancel Auto-Buy?';

  @override
  String get autoBuyCancelMessage =>
      'You will not automatically buy bitcoin next time you fund your account.';

  @override
  String get autoBuyDeactivateConfirm => 'Yes, deactivate';

  @override
  String get autoBuyHowItWorks => 'How it works';

  @override
  String get autoBuyConnectWallet =>
      'Connect your Bitcoin, Lightning, or Liquid wallet';

  @override
  String get autoBuyPurchaseCreated =>
      'A Bitcoin purchase is automatically created each time you fund your Bull Bitcoin account.';

  @override
  String get autoBuyBitcoinSent =>
      'Bitcoin is sent directly to your own wallet.';

  @override
  String get autoBuyRiskDisclaimer =>
      'Order execution cannot be guaranteed. Delays or price changes between the deposit and purchase can change the effective rate.';

  @override
  String get autoBuyGetStarted => 'Get started with Auto-Buy';

  @override
  String get autoBuyConfirmTitle => 'Confirm Auto-Buy';

  @override
  String get autoBuyInfoMessage =>
      'Any amount added to your account will be converted to Bitcoin at the current exchange rate and sent to your wallet.';

  @override
  String get autoBuyAccountUnavailableError =>
      'Your Bull Bitcoin account is not available. Try again later.';

  @override
  String get autoBuyWalletRequiredError =>
      'Add at least one default Bitcoin, Lightning, or Liquid address.';

  @override
  String get autoBuyUpdateError =>
      'Auto-buy could not be updated. Try again later.';
}
