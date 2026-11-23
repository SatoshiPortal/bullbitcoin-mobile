// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'exchange_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class ExchangeLocalizationsIt extends ExchangeLocalizations {
  ExchangeLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get exchangeAccountInfoEmailLabel => 'Email';

  @override
  String get exchangeAccountInfoFirstNameLabel => 'Nome';

  @override
  String get exchangeAccountInfoLastNameLabel => 'Cognome';

  @override
  String get exchangeAccountInfoLoadErrorMessage =>
      'Impossibile caricare le informazioni dell\'account';

  @override
  String get exchangeAccountInfoTitle => 'Informazioni sull\'account';

  @override
  String get exchangeAccountInfoUserNumberCopiedMessage =>
      'Numero utente copiato negli appunti';

  @override
  String get exchangeAccountInfoUserNumberLabel => 'Numero utente';

  @override
  String get exchangeAccountInfoVerificationIdentityVerified =>
      'Identità verificata';

  @override
  String get exchangeAccountInfoVerificationLevelLabel => 'Livello di verifica';

  @override
  String get exchangeAccountInfoVerificationLightVerification =>
      'Verifica di base';

  @override
  String get exchangeAccountInfoVerificationLimitedVerification =>
      'Verifica limitata';

  @override
  String get exchangeAccountInfoVerificationNotVerified => 'Non verificato';

  @override
  String get exchangeAppSettingsDefaultCurrencyLabel =>
      'Valuta fiat predefinita';

  @override
  String get exchangeAppSettingsEmailNotificationsDescription =>
      'Ricevi notifiche e-mail per ordini e aggiornamenti account';

  @override
  String get exchangeAppSettingsEmailNotificationsLabel => 'Notifiche e-mail';

  @override
  String get exchangeAppSettingsPreferredLanguageLabel => 'Lingua preferita';

  @override
  String get exchangeAppSettingsSaveButton => 'Salva';

  @override
  String get exchangeAppSettingsSaveSuccessMessage =>
      'Impostazioni salvate con successo';

  @override
  String get exchangeAppSettingsValidationWarning =>
      'Imposta le preferenze di lingua e valuta prima di salvare.';

  @override
  String get exchangeAuthErrorMessage =>
      'Si è verificato un errore, prova ad accedere di nuovo.';

  @override
  String get exchangeBitcoinWalletsTitle => 'Portafogli Bitcoin predefiniti';

  @override
  String get exchangeErrorNetwork =>
      'Controlla la connessione a Internet e riprova.';

  @override
  String get exchangeErrorSavingPreferences =>
      'Non è stato possibile salvare le tue preferenze. Riprova.';

  @override
  String get exchangeFileUploadButton => 'Caricamento';

  @override
  String get exchangeFileUploadDocumentTitle => 'Caricare qualsiasi documento';

  @override
  String get exchangeFileUploadInstructions =>
      'Se hai bisogno di inviare altri documenti, caricali qui.';

  @override
  String get exchangeFileUploadStatusAccepted => 'Accettato';

  @override
  String get exchangeFileUploadStatusInReview => 'In revisione';

  @override
  String get exchangeFileUploadStatusRejectedBadge => 'Rifiutato';

  @override
  String get exchangeFileUploadSuccess => 'File caricato con successo';

  @override
  String get exchangeFileUploadTapToReupload => 'Tocca per caricare di nuovo';

  @override
  String get exchangeFileUploadTitle => 'Caricamento sicuro file';

  @override
  String get exchangeReferralsApplyToJoinMessage =>
      'Candidati qui per per aderire al programma';

  @override
  String get exchangeReferralsContactSupportMessage =>
      'Contatta l\'assistenza per scoprire il nostro programma referral.';

  @override
  String get exchangeReferralsJoinMissionTitle => 'Unisciti alla missione';

  @override
  String get exchangeReferralsMissionLink => 'bullbitcoin.com/mission';

  @override
  String get exchangeReferralsTitle => 'Referral';

  @override
  String get exchangeSecurityAccessSettingsButton => 'Impostazioni di accesso';

  @override
  String get exchangeSecurityManage2FAPasswordLabel =>
      'Gestione 2FA e password';

  @override
  String get exchangeSettingsAccountInformationTitle =>
      'Informazioni sull\'account';

  @override
  String get exchangeSettingsErrorDocumentAlreadySubmitted =>
      'Un documento è già stato inviato.';

  @override
  String get exchangeSettingsErrorDocumentEmpty =>
      'Questo file è vuoto. Scegline un altro.';

  @override
  String get exchangeSettingsErrorDocumentTooLarge =>
      'Questo file è troppo grande. Scegline uno più piccolo.';

  @override
  String get exchangeSettingsErrorDocumentTypeNotAllowed =>
      'Questo tipo di file non è accettato. Scegline un altro.';

  @override
  String get exchangeSettingsErrorDocumentUnreadable =>
      'Non è stato possibile leggere questo file. Scegline un altro.';

  @override
  String get exchangeSettingsErrorLoadingAccount =>
      'Non è stato possibile caricare i dettagli del tuo account. Riprova.';

  @override
  String get exchangeSettingsErrorLoadingStatistics =>
      'Non è stato possibile caricare le tue statistiche di trading. Riprova.';

  @override
  String get exchangeSettingsErrorLoadingUploadStatus =>
      'Non è stato possibile caricare lo stato del tuo upload. Riprova.';

  @override
  String get exchangeSettingsErrorUploadingDocument =>
      'Non è stato possibile caricare il documento. Riprova.';

  @override
  String get exchangeSettingsLogInTitle => 'Accedi';

  @override
  String get exchangeSettingsRecipientsTitle => 'Destinatari';

  @override
  String get exchangeSettingsReferralsTitle => 'Referral';

  @override
  String get exchangeSettingsSecuritySettingsTitle =>
      'Impostazioni di sicurezza';

  @override
  String get exchangeSettingsTransactionsTitle => 'Transazioni';

  @override
  String exchangeStatisticsAsOf(String date) {
    return 'A partire da $date';
  }

  @override
  String get exchangeStatisticsAveragePrice => 'Prezzo medio';

  @override
  String get exchangeStatisticsBillerStats => 'Statistiche fornitori';

  @override
  String get exchangeStatisticsBuyAvgPriceDesc =>
      'Prezzo medio pagato per bitcoin negli acquisti';

  @override
  String get exchangeStatisticsBuySellRatio => 'Acquisto/vendita';

  @override
  String get exchangeStatisticsBuySellRatioDesc =>
      'Percentuale del volume totale tra acquisti e vendite';

  @override
  String get exchangeStatisticsBuyStats => 'Comprare Statistiche';

  @override
  String get exchangeStatisticsBuyTradeCountDesc =>
      'Numero di transazioni di acquisto di bitcoin';

  @override
  String get exchangeStatisticsBuyVolumeDesc =>
      'Importo totale speso per acquistare bitcoin';

  @override
  String exchangeStatisticsCurrency(String currency) {
    return 'Valuta: $currency';
  }

  @override
  String get exchangeStatisticsNoData => 'Nessuna statistica disponibile';

  @override
  String get exchangeStatisticsOrderStats => 'Statistiche dell\'ordine';

  @override
  String get exchangeStatisticsSellAvgPriceDesc =>
      'Prezzo medio ricevuto per bitcoin nelle vendite';

  @override
  String get exchangeStatisticsSellStats => 'Sell Statistiche';

  @override
  String get exchangeStatisticsSellTradeCountDesc =>
      'Numero di transazioni di vendita di bitcoin';

  @override
  String get exchangeStatisticsSellVolumeDesc =>
      'Importo totale ricevuto dalla vendita di bitcoin';

  @override
  String get exchangeStatisticsTitle => 'Statistiche';

  @override
  String get exchangeStatisticsTotalAmount => 'Importo totale';

  @override
  String get exchangeStatisticsTotalVolume => 'Volume di trading totale';

  @override
  String get exchangeStatisticsTotalVolumeDesc =>
      'Volumi combinati di acquisto e vendita in valute fiat';

  @override
  String get exchangeStatisticsTradeCount => 'Contesto commerciale';

  @override
  String exchangeStatisticsTradeCountByCurrency(int count, String currency) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count operazioni ($currency)',
      one: '1 operazione ($currency)',
    );
    return '$_temp0';
  }

  @override
  String exchangeStatisticsTradeCountValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count operazioni',
      one: '1 operazione',
    );
    return '$_temp0';
  }

  @override
  String get exchangeStatisticsVolume => 'Volume';

  @override
  String get exchangeSupportChatAttachFileTooltip => 'Attach a file';

  @override
  String get exchangeSupportChatAttachLogsFailed =>
      'Impossibile allegare i log. Riprova.';

  @override
  String get exchangeSupportChatAttachLogsTooltip => 'Attach logs';

  @override
  String get exchangeSupportChatAttachmentImage => 'Immagine';

  @override
  String get exchangeSupportChatAttachmentUnknownFile => 'File sconosciuto';

  @override
  String get exchangeSupportChatEmptyState =>
      'Nessun messaggio. Inizia una conversazione!';

  @override
  String get exchangeSupportChatFetchFileDataFailed =>
      'Recupero dei dati del file non riuscito.';

  @override
  String get exchangeSupportChatInputHint => 'Digita un messaggio...';

  @override
  String get exchangeSupportChatLoadAttachmentError =>
      'Impossibile aprire l\'allegato. Riprova.';

  @override
  String get exchangeSupportChatLoadMessagesError =>
      'Impossibile caricare i messaggi. Riprova.';

  @override
  String get exchangeSupportChatMessageEmptyError =>
      'Il messaggio non può essere vuoto';

  @override
  String get exchangeSupportChatMessageRequired => 'È necessario un messaggio';

  @override
  String get exchangeSupportChatPickFilesFailed =>
      'Selezione dei file non riuscita. Riprova.';

  @override
  String get exchangeSupportChatSendMessageError =>
      'Impossibile inviare il messaggio. Riprova.';

  @override
  String get exchangeSupportChatSendTooltip => 'Send message';

  @override
  String get exchangeSupportChatTitle => 'Chat di supporto';

  @override
  String get exchangeSupportChatYesterday => 'Ieri';

  @override
  String get exchangeSupportLoginChatRequired =>
      'Per ottenere supporto umano, devi prima accedere al tuo account Bull Bitcoin. È completamente gratuito e non è richiesto alcun KYC, solo un indirizzo email.';

  @override
  String get loginButton => 'LOGIN';

  @override
  String get notLoggedInTitle => 'Non hai effettuato l\'accesso';

  @override
  String get oopsSomethingWentWrong => 'Ops! Qualcosa non va';

  @override
  String get retry => 'Riprova';

  @override
  String get settingsAppSettingsTitle => 'Impostazioni app';

  @override
  String get exchangeSupportChatLogDraft => 'Here are my logs';

  @override
  String get settingsAccountSettingsTitle => 'Impostazioni account';

  @override
  String get settingsErrorSavingSetting =>
      'Non è stato possibile salvare questa impostazione. Riprova.';

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
