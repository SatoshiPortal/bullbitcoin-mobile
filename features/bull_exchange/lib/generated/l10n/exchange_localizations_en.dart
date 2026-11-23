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

  @override
  String get exchangeAuthLoginFailedTitle => 'Login Failed';

  @override
  String get exchangeAuthLoginFailedMessage =>
      'An error occurred, please try logging in again.';

  @override
  String get exchangeAuthLoginFailedOkButton => 'OK';

  @override
  String get exchangeTradingUnavailable => 'Trading is unavailable.';

  @override
  String get settingsScreenTitle => 'Settings';

  @override
  String get transactionHistoryTitle => 'Transaction History';

  @override
  String get exchangeHomeDepositButton => 'Deposit';

  @override
  String get exchangeHomeWithdrawButton => 'Withdraw';

  @override
  String get exchangeDcaUnableToGetConfig => 'Unable to get DCA configuration';

  @override
  String get exchangeDcaDeactivateTitle => 'Deactivate Recurring Buy';

  @override
  String get exchangeDcaActivateTitle => 'Activate Recurring Buy';

  @override
  String get exchangeDcaHideSettings => 'Hide settings';

  @override
  String get exchangeDcaViewSettings => 'View settings';

  @override
  String get exchangeDcaCancelDialogTitle => 'Cancel Bitcoin Recurring Buy?';

  @override
  String get exchangeDcaCancelDialogMessage =>
      'Your recurring Bitcoin purchase plan will stop, and scheduled buys will end. To restart, you\'ll need to set up a new plan.';

  @override
  String get exchangeDcaCancelDialogCancelButton => 'Cancel';

  @override
  String get exchangeDcaCancelDialogConfirmButton => 'Yes, deactivate';

  @override
  String get exchangeDcaFrequencyHour => 'hour';

  @override
  String get exchangeDcaFrequencyDay => 'day';

  @override
  String get exchangeDcaFrequencyWeek => 'week';

  @override
  String get exchangeDcaFrequencyMonth => 'month';

  @override
  String get exchangeDcaNetworkBitcoin => 'Bitcoin Network';

  @override
  String get exchangeDcaNetworkLightning => 'Lightning Network';

  @override
  String get exchangeDcaNetworkLiquid => 'Liquid Network';

  @override
  String exchangeDcaSummaryMessage(
    String amount,
    String frequency,
    String network,
  ) {
    return 'You are buying $amount every $frequency via $network as long as there are funds in your account.';
  }

  @override
  String exchangeDcaAddressDisplay(String addressLabel, String address) {
    return '$addressLabel: $address';
  }

  @override
  String get exchangeKycLevelLight => 'Light';

  @override
  String get exchangeKycLevelLimited => 'Limited';

  @override
  String get exchangeKycCardTitle => 'Complete your KYC';

  @override
  String get exchangeKycCardSubtitle => 'To remove transaction limits';

  @override
  String get homeActionBuy => 'Buy';

  @override
  String get homeActionSell => 'Sell';

  @override
  String get homeActionPay => 'Pay';

  @override
  String get homeActionTransfer => 'Swap';

  @override
  String get priceChartShowTooltip => 'Show price chart';

  @override
  String get recipientsSearchHint => 'Search recipients by name or label';

  @override
  String get recipientsScreenTitle => 'Select Recipient';

  @override
  String get recipientsScreenSubtitle => 'Who are you paying?';

  @override
  String get recipientsTabNew => 'New Recipient';

  @override
  String get recipientsTabList => 'My Fiat Recipients';

  @override
  String get recipientsPayoutMethod => 'Payout method';

  @override
  String get recipientsFilterByJurisdiction => 'Filter by Jurisdiction:';

  @override
  String get recipientsListEmpty => 'No recipients found.';

  @override
  String get recipientsContinue => 'Continue';

  @override
  String get recipientsJurisdictionAll => 'All Jurisdictions';

  @override
  String get recipientsJurisdictionCanada => '🇨🇦 Canada';

  @override
  String get recipientsJurisdictionEurope => '🇪🇺 Europe (SEPA)';

  @override
  String get recipientsJurisdictionMexico => '🇲🇽 Mexico';

  @override
  String get recipientsJurisdictionCostaRica => '🇨🇷 Costa Rica';

  @override
  String get recipientsJurisdictionArgentina => '🇦🇷 Argentina';

  @override
  String get recipientsJurisdictionColombia => '🇨🇴 Colombia';

  @override
  String get recipientsTypeInteracEmail => 'Email Money Transfer';

  @override
  String get recipientsTypeBillPayment => 'Bill Payment';

  @override
  String get recipientsTypeBankTransfer => 'Bank Transfer';

  @override
  String get recipientsTypeSepa => 'SEPA Transfer';

  @override
  String get recipientsTypeSpeiClabe => 'SPEI CLABE';

  @override
  String get recipientsTypeSpeiSms => 'SPEI SMS';

  @override
  String get recipientsTypeSpeiCard => 'SPEI Card';

  @override
  String get recipientsTypeSinpeIbanUsd => 'SINPE IBAN (USD)';

  @override
  String get recipientsTypeSinpeIbanCrc => 'SINPE IBAN (CRC)';

  @override
  String get recipientsTypeSinpeMovil => 'SINPE Móvil';

  @override
  String get recipientsTypeBankAccountAr => 'CBU/CVU Argentina';

  @override
  String get recipientsTypeBankAccountCo => 'Bank Account COP';

  @override
  String get recipientsTypeNequi => 'Nequi';

  @override
  String get recipientsInfoEmail => 'Email';

  @override
  String get recipientsInfoPayee => 'Payee';

  @override
  String get recipientsInfoAccount => 'Account';

  @override
  String get recipientsInfoPhone => 'Phone';

  @override
  String get recipientsInfoCard => 'Card';

  @override
  String get recipientsInfoLabel => 'Label';

  @override
  String get recipientsValidationFieldRequired => 'This field can\'t be empty';

  @override
  String get recipientsLabelOptional => 'Label (optional)';

  @override
  String get recipientsLabelHint => 'Enter a label for this recipient';

  @override
  String get recipientsFieldName => 'Name';

  @override
  String get recipientsFieldNameHint => 'Enter recipient name';

  @override
  String get recipientsFieldRecipientNameLabel => 'Name of the recipient';

  @override
  String get recipientsFieldPhoneNumber => 'Phone Number';

  @override
  String get recipientsFieldPhoneNumberHint => 'Enter phone number';

  @override
  String get recipientsFieldSinpePhoneNumberHint =>
      '8 digits without country code';

  @override
  String get recipientsFieldDocumentType => 'Recipient ID type';

  @override
  String get recipientsFieldDocumentNumberHint => 'Enter recipient ID number';

  @override
  String get recipientsFieldOwnerName => 'Owner Name';

  @override
  String get recipientsFieldOwnerNameHint => 'Enter owner name';

  @override
  String get recipientsAccountOwnerQuestion =>
      'Who does this account belong to?';

  @override
  String get recipientsAccountOwnerMine => 'This is my account';

  @override
  String get recipientsAccountOwnerSomeoneElse =>
      'This is someone else\'s account';

  @override
  String get recipientsFieldIban => 'IBAN';

  @override
  String get recipientsFieldIbanHint => 'Enter IBAN';

  @override
  String get recipientsFieldClabe => 'CLABE';

  @override
  String get recipientsFieldClabeHint => 'Enter CLABE number';

  @override
  String get recipientsFieldCvuCbu => 'CBU/CVU';

  @override
  String get recipientsFieldCvuCbuHint => 'Enter CVU/CBU number';

  @override
  String get recipientsFieldBankInstitution => 'Bank Institution';

  @override
  String get recipientsFieldBankInstitutionPlaceholder =>
      'Select Bank Institution';

  @override
  String get recipientsValidationBankInstitution =>
      'Please select a bank institution';

  @override
  String get recipientsFieldAccountType => 'Account Type';

  @override
  String get recipientsAccountTypeSavings => 'Savings';

  @override
  String get recipientsAccountTypeChecking => 'Checking';

  @override
  String get recipientsFieldBankAccountNumber => 'Bank Account Number';

  @override
  String get recipientsFieldBankAccountNumberHint =>
      'Enter bank account number';

  @override
  String get recipientsCopDocCc => 'Cédula de Ciudadanía';

  @override
  String get recipientsCopDocCe => 'Cédula de Extranjería';

  @override
  String get recipientsCopDocNit => 'Número de Identificación Tributaria';

  @override
  String get recipientsCopDocPassport => 'Passport';

  @override
  String get recipientsCopDocTi => 'Tarjeta de Identidad';

  @override
  String get recipientsCopDocRegistroCivil => 'Registro Civil';

  @override
  String get recipientsCopDocCcRecipientNumber => 'Recipient cédula number';

  @override
  String get recipientsCopDocCeRecipientNumber =>
      'Recipient cédula de extranjería number';

  @override
  String get recipientsCopDocNitRecipientNumber => 'Recipient tax ID number';

  @override
  String get recipientsCopDocPassportRecipientNumber =>
      'Recipient passport number';

  @override
  String get recipientsCopDocTiRecipientNumber =>
      'Recipient identity card number';

  @override
  String get recipientsCopDocRegistroCivilRecipientNumber =>
      'Recipient civil registry number';

  @override
  String get recipientsFieldDebitCard => 'Debit Card Number';

  @override
  String get recipientsFieldDebitCardHint => 'Enter debit card number';

  @override
  String get recipientsFieldOwnerNameSinpeHint => 'Owner name will appear here';

  @override
  String get recipientsValidationSinpePhoneCountryCode =>
      'Remove the country code (+506). Enter only the 8-digit number';

  @override
  String get recipientsValidationSinpePhoneInvalidChars =>
      'Use digits only (no letters or symbols)';

  @override
  String get recipientsValidationSinpePhoneTooShort =>
      'Enter all 8 digits of the phone number';

  @override
  String get recipientsValidationSinpeOwner =>
      'Please validate the phone number';

  @override
  String get recipientsFieldEmailAddress => 'Email Address';

  @override
  String get recipientsFieldEmailAddressHint => 'Enter email address';

  @override
  String get recipientsFieldSecurityQuestion => 'Security Question';

  @override
  String get recipientsFieldSecurityQuestionHint =>
      'Enter security question (10-40 characters)';

  @override
  String get recipientsFieldSecurityAnswer => 'Security Answer';

  @override
  String get recipientsFieldSecurityAnswerHint => 'Enter security answer';

  @override
  String get recipientsValidationSecurityQuestionMin =>
      'Security question must be at least 10 characters';

  @override
  String recipientsCharCounter(int count) {
    return '$count/40 characters';
  }

  @override
  String get recipientsFieldInstitutionCode => 'Institution Code';

  @override
  String get recipientsFieldInstitutionCodeHint => 'Enter institution code';

  @override
  String get recipientsFieldInstitutionNumber => 'Institution Number';

  @override
  String get recipientsFieldInstitutionNumberHint => 'Enter institution number';

  @override
  String get recipientsFieldTransitNumber => 'Transit Number';

  @override
  String get recipientsFieldTransitNumberHint => 'Enter transit number';

  @override
  String get recipientsFieldAccountNumber => 'Account Number';

  @override
  String get recipientsFieldAccountNumberHint => 'Enter account number';

  @override
  String get recipientsFieldDefaultComment => 'Default Comment (optional)';

  @override
  String get recipientsFieldDefaultCommentHint => 'Enter default comment';

  @override
  String get recipientsFieldCorporateAccount => 'Corporate account';

  @override
  String get recipientsFieldFirstName => 'First Name';

  @override
  String get recipientsFieldFirstNameHint => 'Enter first name';

  @override
  String get recipientsFieldLastName => 'Last Name';

  @override
  String get recipientsFieldLastNameHint => 'Enter last name';

  @override
  String get recipientsFieldCorporateName => 'Corporate Name';

  @override
  String get recipientsFieldCorporateNameHint => 'Enter corporate name';

  @override
  String get recipientsFieldBillerName => 'Biller Name';

  @override
  String get recipientsFieldBillerNameHint => 'Search and select a biller';

  @override
  String get recipientsValidationBillerSearchMin =>
      'Enter 3 or more characters to search';

  @override
  String get recipientsValidationBillerSelect =>
      'Please select a biller from the list';

  @override
  String get recipientsFieldPayeeAccountNumber => 'Payee Account Number';

  @override
  String get recipientsErrorLoadFailed =>
      'Your recipients could not be loaded. Please try again.';

  @override
  String get recipientsErrorSaveFailed =>
      'This recipient could not be saved. Please check the details and try again.';

  @override
  String get recipientsErrorSinpeLookupFailed =>
      'We could not verify this phone number. Please check it and try again.';

  @override
  String get recipientsErrorBillerSearchFailed =>
      'Billers could not be searched. Please try again.';

  @override
  String get recipientsErrorNetwork =>
      'Check your internet connection and try again.';

  @override
  String get recipientsListPullToRetry => 'Pull down to retry.';

  @override
  String get recipientsErrorSavedButNotSelected =>
      'This recipient was saved, but we could not continue. Find them in your list to carry on.';

  @override
  String get recipientsTypeConfidentialSepa => 'Confidential SEPA';

  @override
  String get recipientsErrorVirtualIbanNotAvailable =>
      'You do not have the required permissions to access this funding option. Either your KYC is insufficient or this option is not available for your account';

  @override
  String get recipientsErrorEuResidencyRequired =>
      'You need to be a resident of the European Union to activate Confidential SEPA.';

  @override
  String get recipientsConfidentialSepaActivatingTitle =>
      'Activating recipient';

  @override
  String get recipientsConfidentialSepaActivatingDescription =>
      'Your recipient is being activated for Confidential SEPA. This may take a few minutes. We\'ll notify you when ready.';

  @override
  String get recipientsConfidentialSepaNotActivatedTitle =>
      'Recipient not activated for Confidential SEPA';

  @override
  String get recipientsConfidentialSepaNotActivatedDescription =>
      'This recipient is not activated for Confidential SEPA yet. We are activating it now. This may take a few minutes. We\'ll notify you when ready. You can use Instant and Regular SEPA instead.';

  @override
  String get recipientsConfidentialSepaActivatedTitle => 'Recipient activated';

  @override
  String get recipientsConfidentialSepaActivatedDescription =>
      'Your recipient is now active for Confidential SEPA.';

  @override
  String get recipientsConfidentialSepaUseRegularSepa =>
      'Use Instant and Regular SEPA instead';

  @override
  String get recipientsReturnHome => 'Return Home';

  @override
  String get recipientsVirtualIbanIntroTitle => 'Activate Confidential SEPA?';

  @override
  String get recipientsVirtualIbanNewBadge => 'New';

  @override
  String get recipientsVirtualIbanIntroDescription =>
      'Fund your account privately using a personal virtual IBAN in your own name. It\'s free.';

  @override
  String get recipientsVirtualIbanIntroSelfTransfer =>
      'When sending funds to Bull Bitcoin from your bank, it appears as a transfer to yourself.';

  @override
  String get recipientsVirtualIbanIntroNoTransferCode =>
      'No transfer code required.';

  @override
  String get recipientsVirtualIbanNameWarningTitle =>
      'Important: Name Matching Required';

  @override
  String get recipientsVirtualIbanNameWarningDescription =>
      'Bank account name must exactly match your Bull Bitcoin virtual IBAN name, or the transfer will be returned automatically. Names don\'t match? Contact support.';

  @override
  String get recipientsVirtualIbanAccountOwnerName => 'Account Owner Name';

  @override
  String get recipientsVirtualIbanNameConfirmation =>
      'I confirm the name matches my bank account(s)';

  @override
  String get recipientsVirtualIbanActivate => 'Activate Confidential SEPA';

  @override
  String get recipientsVirtualIbanActivatingTitle =>
      'Activating Confidential SEPA...';

  @override
  String get recipientsVirtualIbanActivatingDescription =>
      'Creating your virtual IBAN. This may take a few minutes. We\'ll notify you when ready.';

  @override
  String get recipientsVirtualIbanActivatedTitle =>
      'Confidential SEPA Activated';

  @override
  String get recipientsVirtualIbanActivatedDescription =>
      'You can now use your personal virtual IBAN to withdraw money privately.';

  @override
  String get recipientsVirtualIbanCopied => 'Copied to clipboard';

  @override
  String get recipientsVirtualIbanDone => 'Done';

  @override
  String get recipientsVirtualIbanRecipientName => 'Recipient name';

  @override
  String get recipientsVirtualIbanIbanLabel => 'Virtual IBAN Account Number';

  @override
  String get recipientsVirtualIbanCountry => 'Bank account country';

  @override
  String get recipientsVirtualIbanBic => 'BIC code';

  @override
  String get recipientsVirtualIbanActivatedFundingDescription =>
      'You can now use your personal virtual IBAN to deposit money privately.';

  @override
  String get recipientsVirtualIbanShowDetails => 'Show my virtual IBAN details';

  @override
  String get recipientsVirtualIbanDetailsDescription =>
      'Fund your account privately using a personal virtual IBAN in your own name. The deposit will appear as a payment to yourself, with no transfer code required.';

  @override
  String get recipientsVirtualIbanBankAddress => 'Bank address';

  @override
  String get recipientsVirtualIbanBankAddressHelp =>
      'The official bank address, in case your bank asks for it.';

  @override
  String get recipientsConfidentialSepaNameMustMatchHint =>
      'Names must match between your bank and virtual IBAN accounts or transfers will be returned automatically.';

  @override
  String get recipientsFieldBankAccountIban => 'Bank account number (IBAN)';

  @override
  String get recipientsTypeConfidentialSepaDescription =>
      'Withdrawals appear as a self-transfer with your account name';

  @override
  String get withdrawAmountTitle => 'Withdraw fiat';

  @override
  String get withdrawAmountContinue => 'Continue';

  @override
  String get withdrawConfirmTitle => 'Confirm withdrawal';

  @override
  String get withdrawConfirmRecipientName => 'Recipient name';

  @override
  String get withdrawConfirmAmount => 'Amount';

  @override
  String get withdrawConfirmEmail => 'Email';

  @override
  String get withdrawConfirmPayee => 'Payee';

  @override
  String get withdrawConfirmAccount => 'Account';

  @override
  String get withdrawConfirmIban => 'IBAN';

  @override
  String get withdrawConfirmClabe => 'CLABE';

  @override
  String get withdrawConfirmPhone => 'Phone';

  @override
  String get withdrawConfirmCard => 'Card';

  @override
  String get withdrawConfirmButton => 'Confirm withdrawal';

  @override
  String get withdrawSuccessTitle => 'Withdrawal Initiated';

  @override
  String get withdrawSuccessOrderDetails => 'Order details';

  @override
  String get withdrawConfirmBankAccount => 'Bank account';

  @override
  String get withdrawOwnershipQuestion => 'Who does this account belong to?';

  @override
  String get withdrawOwnershipMyAccount => 'This is my account';

  @override
  String get withdrawOwnershipOtherAccount => 'This is someone else\'s account';

  @override
  String get withdrawUnauthenticatedError =>
      'You are not authenticated. Please log in to continue.';

  @override
  String withdrawBelowMinAmountError(String amount, String currency) {
    return 'Minimum amount is $amount $currency';
  }

  @override
  String withdrawAboveMaxAmountError(String amount, String currency) {
    return 'Maximum amount is $amount $currency';
  }

  @override
  String get withdrawInteracSecurityDetailsTitle => 'Transfer security details';

  @override
  String get withdrawInteracSaveAsDefault => 'Save these details as default';

  @override
  String get withdrawInteracSecurityQuestionLengthError =>
      'Security question must be 3-40 characters';

  @override
  String get withdrawInteracSecurityAnswerLengthError =>
      'Security answer must be 3-40 characters';

  @override
  String get withdrawInteracSecurityAnswerFormatError =>
      'Use letters, numbers, or hyphens without spaces';

  @override
  String get withdrawUnexpectedError =>
      'Your withdrawal could not be completed right now. Please try again or contact support.';

  @override
  String get withdrawConfidentialSepaNotActivatedError =>
      'Please activate the confidential payment option for this SEPA recipient.';

  @override
  String get limitOrdersTitle => 'Limit orders';

  @override
  String get limitOrdersActiveTitle => 'Active limit orders';

  @override
  String get limitOrdersCreateNew => 'Create new';

  @override
  String get limitOrdersMaximumActiveHint =>
      'Cancel an active order before creating another one.';

  @override
  String limitOrdersBuyAt(String price) {
    return 'Buy at $price';
  }

  @override
  String get limitOrdersCancelAll => 'Cancel all';

  @override
  String get limitOrdersCancelAllTitle => 'Cancel all active limit orders?';

  @override
  String get limitOrdersCancelAllMessage =>
      'This is permanent. None of these orders will execute after cancellation.';

  @override
  String get limitOrdersDialogConfirm => 'Confirm';

  @override
  String get limitOrdersDone => 'Done';

  @override
  String get limitOrdersTargetPrice => 'Target price';

  @override
  String get limitOrdersFiatAmount => 'Amount';

  @override
  String get limitOrdersEstimatedBuyPrice => 'Estimated buy price';

  @override
  String get limitOrderDetailsTitle => 'Limit order details';

  @override
  String get limitOrderDetailsStatus => 'Status';

  @override
  String get limitOrderDetailsNumber => 'Order number';

  @override
  String get limitOrderDetailsAddress => 'Payout address';

  @override
  String get limitOrderDetailsCreated => 'Created';

  @override
  String get limitOrderDetailsExpires => 'Expires';

  @override
  String get limitOrderCancel => 'Cancel limit order';

  @override
  String get limitOrderCancelTitle => 'Cancel this limit order?';

  @override
  String get limitOrderCancelMessage =>
      'Cancellation is permanent and this order will no longer execute.';

  @override
  String get limitOrderStatusActive => 'Active';

  @override
  String get limitOrderStatusExecuted => 'Executed';

  @override
  String get limitOrderStatusCancelled => 'Cancelled';

  @override
  String get limitOrderStatusExpired => 'Expired';

  @override
  String get limitOrderStatusFailed => 'Failed';

  @override
  String get limitOrdersAccountUnavailableError =>
      'Your Bull Bitcoin account or balances could not be loaded. Please try again.';

  @override
  String get limitOrderNotFoundError => 'This limit order could not be found.';

  @override
  String get limitOrdersLoadError =>
      'Limit orders could not be loaded. Please try again.';

  @override
  String get limitOrderCancellationError =>
      'The limit order could not be cancelled. Please try again.';

  @override
  String get limitOrderDetailsEstimatedBitcoin => 'Estimated bitcoin';

  @override
  String get limitOrdersMaximumActiveError =>
      'You already have five active limit orders. Cancel one before creating another.';

  @override
  String get limitOrderInvalidAddressError =>
      'The selected payout address is not valid.';

  @override
  String get limitOrderCreationError =>
      'The limit order could not be created. Please try again.';

  @override
  String get exchangeSettingsLogOutTitle => 'Log Out';

  @override
  String get logoutConfirmationTitle => 'Confirm Logout';

  @override
  String get logoutConfirmationDescription =>
      'Are you sure you want to log out of your Bull Bitcoin account? You will need to log in again to access exchange features.';

  @override
  String get logoutConfirmationCancel => 'Cancel';

  @override
  String get logoutConfirmationLogout => 'Logout';

  @override
  String get exchangeSettingsDeleteAccountTitle => 'Delete Account';

  @override
  String get deleteAccountConfirmationTitle => 'Delete Account';

  @override
  String get deleteAccountConfirmationDescription =>
      'This will send an account deletion request to our support team. Your account will be deleted within 5 working days.';

  @override
  String get deleteAccountConfirmationCancel => 'Cancel';

  @override
  String get deleteAccountConfirmationDelete => 'Delete Account';

  @override
  String get deleteAccountSuccessTitle => 'Account Deletion Requested';

  @override
  String get deleteAccountSuccessDescription =>
      'Your account deletion request has been made. It will be processed within 5 working days.';

  @override
  String get deleteAccountSuccessClose => 'Close';

  @override
  String get buyEnterAmount => 'Enter amount';

  @override
  String get buyPaymentMethod => 'Payment method';

  @override
  String get buyMax => 'Max';

  @override
  String get buySelectWallet => 'Select wallet';

  @override
  String get buyEnterBitcoinAddress => 'Enter bitcoin address';

  @override
  String get buyBitcoinAddressHint => 'BC1QYL7J673H…6Y6ALV70M0';

  @override
  String get buyConfirmPurchase => 'Confirm purchase';

  @override
  String buyYouBought(String amount, String fiatAmount) {
    return 'You bought $amount with $fiatAmount';
  }

  @override
  String get buyPayoutWillBeSentIn => 'Your payout will be sent in ';

  @override
  String get buyViewDetails => 'View details';

  @override
  String get buyAccelerateTransaction => 'Accelerate Transaction';

  @override
  String get buyGetConfirmedFaster => 'Get it confirmed faster';

  @override
  String get buyConfirmExpressWithdrawal => 'Confirm express withdrawal';

  @override
  String get buyNetworkFeeExplanation =>
      'The Bitcoin network fee will be deducted from the amount you receive and collected by the Bitcoin miners';

  @override
  String get buyNetworkFees => 'Network fees';

  @override
  String get buyEstimatedFeeValue => 'Estimated fee value';

  @override
  String get buyNetworkFeeRate => 'Network fee rate';

  @override
  String get buyConfirmationTime => 'Confirmation time';

  @override
  String get buyConfirmationTimeValue => '~10 minutes';

  @override
  String get buyWaitForFreeWithdrawal => 'Wait for free withdrawal';

  @override
  String get buyConfirmExpress => 'Confirm express';

  @override
  String get buyBitcoinSent => 'Bitcoin sent!';

  @override
  String get buyThatWasFast => 'That was fast, wasn\'t it?';

  @override
  String get globalDefaultBitcoinWalletLabel => 'Secure Bitcoin';

  @override
  String get globalDefaultLiquidWalletLabel => 'Instant payments';

  @override
  String get dcaSuccessTitle => 'Recurring Buy is Active!';

  @override
  String dcaSuccessMessageHourly(String amount) {
    return 'You will buy $amount every hour';
  }

  @override
  String dcaSuccessMessageDaily(String amount) {
    return 'You will buy $amount every day';
  }

  @override
  String dcaSuccessMessageWeekly(String amount) {
    return 'You will buy $amount every week';
  }

  @override
  String dcaSuccessMessageMonthly(String amount) {
    return 'You will buy $amount every month';
  }

  @override
  String get dcaBackToHomeButton => 'Back to home';

  @override
  String get dcaChooseWalletTitle => 'Choose Bitcoin Wallet';

  @override
  String get dcaWalletSelectionDescription =>
      'Bitcoin purchases will be placed automatically per this schedule.';

  @override
  String get dcaNetworkValidationError => 'Please select a network';

  @override
  String get dcaEnterLightningAddressLabel => 'Enter Lightning Address';

  @override
  String get dcaUseDefaultLightningAddress =>
      'Use my default Lightning address.';

  @override
  String get dcaWalletSelectionContinueButton => 'Continue';

  @override
  String get dcaSelectFrequencyLabel => 'Select Frequency';

  @override
  String get dcaSelectWalletTypeLabel => 'Select Bitcoin Wallet Type';

  @override
  String get dcaWalletTypeBitcoin => 'Bitcoin (BTC)';

  @override
  String get dcaWalletTypeLightning => 'Lightning Network (LN)';

  @override
  String get dcaWalletTypeLiquid => 'Liquid (LBTC)';

  @override
  String get dcaWalletBitcoinSubtitle => 'Minimum 0.001 BTC';

  @override
  String get dcaWalletLightningSubtitle =>
      'Requires compatible wallet, maximum 0.25 BTC';

  @override
  String get dcaWalletLiquidSubtitle => 'Requires compatible wallet';

  @override
  String get dcaSetupTitle => 'Set Recurring Buy';

  @override
  String get dcaSetupInsufficientBalance => 'Insufficient Balance';

  @override
  String get dcaSetupInsufficientBalanceMessage =>
      'You do not have enough balance to create this order.';

  @override
  String get dcaSetupFundAccount => 'Fund your account';

  @override
  String get dcaSetupScheduleMessage =>
      'Bitcoin purchases will be placed automatically per this schedule.';

  @override
  String get dcaSetupFrequencyError => 'Please select a frequency';

  @override
  String get dcaSetupContinue => 'Continue';

  @override
  String get dcaConfirmTitle => 'Confirm Recurring Buy';

  @override
  String get dcaConfirmAutoMessage =>
      'Buy orders will be placed automatically per these settings. You can disable them anytime.';

  @override
  String get dcaConfirmFrequency => 'Frequency';

  @override
  String get dcaConfirmFrequencyHourly => 'Every hour';

  @override
  String get dcaConfirmFrequencyDaily => 'Every day';

  @override
  String get dcaConfirmFrequencyWeekly => 'Every week';

  @override
  String get dcaConfirmFrequencyMonthly => 'Every month';

  @override
  String get dcaConfirmAmount => 'Amount';

  @override
  String get dcaConfirmPaymentMethod => 'Payment method';

  @override
  String dcaConfirmPaymentBalance(String currency) {
    return '$currency balance';
  }

  @override
  String get dcaConfirmOrderType => 'Order type';

  @override
  String get dcaConfirmOrderTypeValue => 'Recurring buy';

  @override
  String get dcaConfirmNetwork => 'Network';

  @override
  String get dcaConfirmNetworkBitcoin => 'Bitcoin';

  @override
  String get dcaConfirmNetworkLightning => 'Lightning';

  @override
  String get dcaConfirmNetworkLiquid => 'Liquid';

  @override
  String get dcaConfirmLightningAddress => 'Lightning address';

  @override
  String get dcaConfirmContinue => 'Continue';

  @override
  String get buyInputTitle => 'Buy Bitcoin';

  @override
  String get buyInputMinAmountError => 'You should buy at least';

  @override
  String get buyInputMaxAmountError => 'You can\'t buy more than';

  @override
  String get buyInputKycPending => 'KYC ID Verification Pending';

  @override
  String get buyInputKycMessage => 'You must complete ID Verification first';

  @override
  String get buyInputCompleteKyc => 'Complete KYC';

  @override
  String get buyInputInsufficientBalance => 'Insufficient balance';

  @override
  String get buyInputInsufficientBalanceMessage =>
      'You do not have enough balance to create this order.';

  @override
  String get buyInputFundAccount => 'Fund your account';

  @override
  String get buyInputContinue => 'Continue';

  @override
  String get buyConfirmTitle => 'Buy Bitcoin';

  @override
  String get buyConfirmYouPay => 'You pay';

  @override
  String get buyConfirmYouReceive => 'You receive';

  @override
  String get buyConfirmBitcoinPrice => 'Bitcoin Price';

  @override
  String get buyConfirmPayoutWallet => 'Payout wallet';

  @override
  String get buyConfirmPayoutMethod => 'Payout method';

  @override
  String get buyPayoutMethodLiquid => 'L-BTC on Liquid';

  @override
  String get buyPayoutMethodBitcoin => 'BTC on Bitcoin chain';

  @override
  String get buyConfirmExternalWallet => 'External Bitcoin wallet';

  @override
  String get buyConfirmAwaitingConfirmation => 'Awaiting confirmation ';

  @override
  String get buyUnauthenticatedError =>
      'You are not authenticated. Please log in to continue.';

  @override
  String get buyBelowMinAmountError =>
      'You are trying to buy below the minimum amount.';

  @override
  String get buyAboveMaxAmountError =>
      'You are trying to buy above the maximum amount.';

  @override
  String get buyUnexpectedError =>
      'Your order could not be created right now. Please try again or contact support.';

  @override
  String get dcaAccountUnavailableError =>
      'Could not load your account. Check your connection, make sure you are logged in, and try again.';

  @override
  String get dcaLightningAddressRequiredError =>
      'Enter a Lightning address to receive your purchases.';

  @override
  String get dcaReceiveAddressError =>
      'Could not prepare a receiving address in your wallet. Please try again.';

  @override
  String get dcaOrderCreationError =>
      'The recurring buy could not be created. Please try again later.';

  @override
  String get payjoinInProgress => 'Payjoin in progress';

  @override
  String get payjoinSucceeded => 'Payjoin succeeded';

  @override
  String get payjoinBuyRegularSend =>
      'Bitcoin sent to your wallet via regular send';

  @override
  String get payjoinUseToggle => 'Use payjoin';

  @override
  String get limitOrdersLightningAddressHint => 'you@domain.com';

  @override
  String get exchangeQuoteUnavailableError =>
      'We couldn\'t get a fresh price. Try again, or go back and start a new order.';

  @override
  String get buyQuoteExpiredError =>
      'This price has expired. A new one is being loaded; check it before confirming.';

  @override
  String get sellTitle => 'Sell Bitcoin';

  @override
  String get sellSelectWallet => 'Select Wallet';

  @override
  String get sellWhichWalletQuestion =>
      'Which wallet do you want to sell from?';

  @override
  String get sellExternalWallet => 'External wallet';

  @override
  String get sellFromAnotherWallet => 'Sell from another Bitcoin wallet';

  @override
  String get sellAboveMaxAmountError =>
      'You are trying to sell above the maximum amount that can be sold with this wallet.';

  @override
  String get sellBelowMinAmountError =>
      'You are trying to sell below the minimum amount that can be sold with this wallet.';

  @override
  String get sellInsufficientBalanceError =>
      'Insufficient balance in the selected wallet to complete this sell order.';

  @override
  String get sellUnauthenticatedError =>
      'You are not authenticated. Please log in to continue.';

  @override
  String get sellOrderNotFoundError =>
      'The sell order was not found. Please try again.';

  @override
  String get sellOrderAlreadyConfirmedError =>
      'This sell order has already been confirmed.';

  @override
  String get sellSelectNetwork => 'Select Network';

  @override
  String get sellHowToPayInvoice => 'How do you want to pay this invoice?';

  @override
  String get sellBitcoinOnChain => 'Bitcoin on-chain';

  @override
  String get sellLightningNetwork => 'Lightning Network';

  @override
  String get sellLiquidNetwork => 'Liquid Network';

  @override
  String get sellConfirmPayment => 'Confirm payment';

  @override
  String get sellPriceWillRefreshIn => 'Price will refresh in ';

  @override
  String get sellOrderNumber => 'Order number';

  @override
  String get sellPayoutRecipient => 'Payout recipient';

  @override
  String get sellCadBalance => 'CAD Balance';

  @override
  String get sellCrcBalance => 'CRC Balance';

  @override
  String get sellEurBalance => 'EUR Balance';

  @override
  String get sellUsdBalance => 'USD Balance';

  @override
  String get sellMxnBalance => 'MXN Balance';

  @override
  String get sellArsBalance => 'ARS Balance';

  @override
  String get sellCopBalance => 'COP Balance';

  @override
  String get sellPayinAmount => 'Payin amount';

  @override
  String get sellPayoutAmount => 'Payout amount';

  @override
  String get sellExchangeRate => 'Exchange rate';

  @override
  String get sellPayFromWallet => 'Pay from wallet';

  @override
  String get sellInstantPayments => 'Instant payments';

  @override
  String get sellSecureBitcoinWallet => 'Secure Bitcoin wallet';

  @override
  String get sellFeePriority => 'Fee Priority';

  @override
  String get sellFastest => 'Fastest';

  @override
  String get sellAdvancedSettings => 'Advanced Settings';

  @override
  String get sellAdvancedOptions => 'Advanced options';

  @override
  String get sellReplaceByFeeActivated => 'Replace-by-fee activated';

  @override
  String get sellSelectCoinsManually => 'Select coins manually';

  @override
  String get sellDone => 'Done';

  @override
  String get sellPleasePayInvoice => 'Please pay this invoice';

  @override
  String get sellBitcoinAmount => 'Bitcoin amount';

  @override
  String get sellCopyInvoice => 'Copy invoice';

  @override
  String get sellShowQrCode => 'Show QR code';

  @override
  String get sellQrCode => 'QR Code';

  @override
  String get sellNoInvoiceData => 'No invoice data available';

  @override
  String get sellInProgress => 'Sell in progress…';

  @override
  String get sellGoHome => 'Go home';

  @override
  String get sellOrderCompleted => 'Order completed!';

  @override
  String get sellBalanceWillBeCredited =>
      'Your account balance will be credited after your transaction receives 1 confirmation onchain.';

  @override
  String sellYouSold(String amount, String fiatAmount) {
    return 'You sold $amount for $fiatAmount';
  }

  @override
  String get payTitle => 'Pay';

  @override
  String get payDescriptionLabel => 'Payment description (optional)';

  @override
  String get payDescriptionHint => 'Add a note for this payment';

  @override
  String get payPaymentDescription => 'Payment description';

  @override
  String get payRecipientType => 'Recipient type';

  @override
  String get payRecipientName => 'Recipient name';

  @override
  String get payRecipientDetails => 'Recipient details';

  @override
  String get payNoDetailsAvailable => 'No details available';

  @override
  String get paySelectWallet => 'Select Wallet';

  @override
  String get payExternalWallet => 'External wallet';

  @override
  String payAboveMaxAmountError(String amount) {
    return 'The maximum you can pay with this wallet is $amount.';
  }

  @override
  String payBelowMinAmountError(String amount) {
    return 'The minimum you can pay with this wallet is $amount.';
  }

  @override
  String get payInsufficientBalanceError =>
      'Insufficient balance in the selected wallet to complete this pay order.';

  @override
  String get payUnauthenticatedError =>
      'You are not authenticated. Please log in to continue.';

  @override
  String get paySelectNetwork => 'Select Network';

  @override
  String get payHowToPayInvoice => 'How do you want to pay this invoice?';

  @override
  String get payLightningNetwork => 'Lightning Network';

  @override
  String get payLiquidNetwork => 'Liquid Network';

  @override
  String get payConfirmPayment => 'Confirm Payment';

  @override
  String get payOrderNumber => 'Order number';

  @override
  String get payPayinAmount => 'Payin amount';

  @override
  String get payPayoutAmount => 'Payout amount';

  @override
  String get payExchangeRate => 'Exchange rate';

  @override
  String get payPayFromWallet => 'Pay from wallet';

  @override
  String get payInstantPayments => 'Instant payments';

  @override
  String get paySecureBitcoinWallet => 'Secure Bitcoin wallet';

  @override
  String get payFeePriority => 'Fee Priority';

  @override
  String get payFastest => 'Fastest';

  @override
  String get payNetworkFees => 'Network fees';

  @override
  String get payAdvancedSettings => 'Advanced Settings';

  @override
  String get payAdvancedOptions => 'Advanced options';

  @override
  String get paySelectCoinsManually => 'Select coins manually';

  @override
  String get payDone => 'Done';

  @override
  String get payContinue => 'Continue';

  @override
  String get payPleasePayInvoice => 'Please pay this invoice';

  @override
  String get payBitcoinAmount => 'Bitcoin amount';

  @override
  String get payBitcoinPrice => 'Bitcoin Price';

  @override
  String get payCopyInvoice => 'Copy Invoice';

  @override
  String get payShowQrCode => 'Show QR code';

  @override
  String get payQrCode => 'QR Code';

  @override
  String get payNoInvoiceData => 'No invoice data available';

  @override
  String get payInvalidState => 'Invalid state';

  @override
  String get payViewDetails => 'View details';

  @override
  String get paySinpeReceipt => 'SINPE Receipt';

  @override
  String get payCompleted => 'Payment Completed!';

  @override
  String payCompletedDescriptionDetails(String fiatAmount, String recipient) {
    return 'The payment of $fiatAmount to $recipient has been completed.';
  }

  @override
  String get paySinpeEnviado => 'SINPE ENVIADO!';

  @override
  String get payOrderDetails => 'Order Details';

  @override
  String get paySinpeMonto => 'Amount';

  @override
  String get paySinpeNumeroOrden => 'Order number';

  @override
  String get paySinpeNumeroComprobante => 'Reference number';

  @override
  String get paySinpeBeneficiario => 'Beneficiary';

  @override
  String get paySinpeOrigen => 'Origin';

  @override
  String get payNotAvailable => 'N/A';

  @override
  String get payBitcoinOnchain => 'Bitcoin on-chain';

  @override
  String get payPaymentInProgress => 'Payment In Progress!';

  @override
  String payPaymentInProgressDescriptionDetails(
    String fiatAmount,
    String recipient,
  ) {
    return 'The payment of $fiatAmount to $recipient will be sent after your transaction receives 1 confirmation onchain.';
  }

  @override
  String payPaymentPayinConfirmedDescriptionDetails(
    String fiatAmount,
    String recipient,
  ) {
    return 'Your transaction is confirmed. The payment of $fiatAmount to $recipient is being processed.';
  }

  @override
  String get payPriceRefreshIn => 'Price will refresh in ';

  @override
  String get payWhichWallet => 'Which wallet do you want to pay from?';

  @override
  String get payExternalWalletDescription => 'Pay from another Bitcoin wallet';

  @override
  String get payRbfActivated => 'Replace-by-fee activated';

  @override
  String get copyDialogButton => 'Copy';

  @override
  String get closeDialogButton => 'Close';

  @override
  String get sellCompleteKYC => 'Complete KYC';

  @override
  String get sellSendPaymentNetworkFees => 'Network fees';

  @override
  String get sellSendPaymentContinue => 'Continue';

  @override
  String get exchangeSendingPayment => 'Sending payment…';

  @override
  String get exchangePaymentSentRefreshingOrder =>
      'Payment sent, refreshing your order…';

  @override
  String get sellBitcoinPriceLabel => 'Bitcoin Price';

  @override
  String get sellViewDetailsButton => 'View details';

  @override
  String get sellKycPendingTitle => 'KYC ID Verification Pending';

  @override
  String get sellKycPendingDescription =>
      'You must complete ID verification first';

  @override
  String get sellLoadingGeneric => 'Loading…';

  @override
  String get viewerTapToCopy => 'Tap to copy';

  @override
  String get invoiceViewerTitle => 'Invoice';

  @override
  String get payjoinViaPayjoin => 'via Payjoin';

  @override
  String get payjoinViaRegularSend => 'via regular send';

  @override
  String get sellDepositAddress => 'Deposit address';

  @override
  String get payDepositAddress => 'Deposit address';

  @override
  String get sellDepositAddressChangedError =>
      'The deposit address of this order changed unexpectedly. For your security, do not pay this order: go back and create a new one.';

  @override
  String get payDepositAddressChangedError =>
      'The deposit address of this order changed unexpectedly. For your security, do not pay this order: go back and create a new one.';

  @override
  String get sellUnexpectedError =>
      'Your sell order could not be completed right now. Please try again or contact support.';

  @override
  String get sellErrorFeeBelowRelayFloor =>
      'Network fee too low. Choose a higher fee.';

  @override
  String get sellErrorFeesUnavailable =>
      'Network fees could not be loaded. Check your connection and try again.';

  @override
  String get payUnexpectedError =>
      'Your payment could not be completed right now. Please try again or contact support.';

  @override
  String get payErrorFeeBelowRelayFloor =>
      'Network fee too low. Choose a higher fee.';

  @override
  String get payErrorFeesUnavailable =>
      'Network fees could not be loaded. Check your connection and try again.';

  @override
  String get withdrawRecipientsPrompt =>
      'Where and how should we send the money?';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get sellQuoteExpiredError =>
      'This price has expired. A new one is being loaded; check it before confirming.';

  @override
  String get exchangePaymentSentPastDeadline =>
      'Payment sent. The exchange reports that the payment deadline for this order expired. Keep the transaction ID below and contact support if the order is not updated.';

  @override
  String get exchangePaymentSentLeave => 'Leave';

  @override
  String get payQuoteExpiredError =>
      'This price has expired. A new one is being loaded; check it before confirming.';

  @override
  String get sellPayoutBalance => 'Add to my account balance';

  @override
  String get sellPayoutSepaDescription =>
      'Withdrawals appear as sent by Leonod';

  @override
  String get sellPayoutTitle => 'Select recipient';

  @override
  String get sellPayoutNewBadge => 'NEW';

  @override
  String get walletSpendAwaitingObservation =>
      'Spending is unavailable until this wallet is synced and has seen its previous payments on the network. Refresh the wallet or use Scan for missing transactions, then try again.';

  @override
  String get sendPayjoinSpendPaused =>
      'This Payjoin payment is paused because the wallet cannot safely continue. Its inputs remain reserved. Refresh the wallet or use Scan for missing transactions, then retry this proposal while it is still valid. If it has expired, check the payment in Transactions before taking further action.';

  @override
  String get exchangePayinNetworkMismatch =>
      'The selected wallet does not match this order’s network or the app’s current environment. Select a compatible wallet and try again.';

  @override
  String get walletSpendBusy => 'The wallet is busy. Try again in a moment.';

  @override
  String get broadcastSignedTxErrorOutcomeUnknown =>
      'We couldn\'t confirm that your transaction was broadcast. Check a block explorer before trying again.';

  @override
  String get sendSelectedUtxosInsufficient =>
      'Selected utxos does not cover required amount';

  @override
  String get selectAmountTitle => 'Select amount';

  @override
  String amountRequestedLabel(String amount) {
    return 'Amount requested: $amount';
  }

  @override
  String get addressLabel => 'Address: ';

  @override
  String get typeLabel => 'Type: ';

  @override
  String get coinsKeychainReceive => 'Receive';

  @override
  String get coinsKeychainChange => 'Change';
}
