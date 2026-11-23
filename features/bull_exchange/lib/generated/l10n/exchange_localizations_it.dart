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
  String get fundExchangeTitle => 'Deposito';

  @override
  String get fundExchangeAccountTitle => 'Deposita sul tuo conto';

  @override
  String get fundExchangeAccountSubtitle =>
      'Seleziona il paese e il metodo di pagamento';

  @override
  String get fundExchangeRestrictedTitle => 'Depositi non disponibili';

  @override
  String get fundExchangeRestrictedMessage =>
      'I depositi non sono disponibili per il tuo conto. Contatta l\'assistenza per maggiori informazioni.';

  @override
  String get fundExchangeWarningTitle => 'Attento ai truffatori';

  @override
  String get fundExchangeWarningDescription =>
      'Se qualcuno ti chiede di comprare Bitcoin o dice di volerti \"aiutare\", fai attenzione: potrebbe trattarsi di una truffa!';

  @override
  String get fundExchangeWarningTacticsTitle =>
      'Tattiche comuni dei truffatori';

  @override
  String get fundExchangeWarningTactic1 =>
      'Ti promettono rendimenti sugli investimenti';

  @override
  String get fundExchangeWarningTactic2 => 'Ti stanno offrendo un prestito';

  @override
  String get fundExchangeWarningTactic3 =>
      'Dicono di lavorare per il recupero crediti o per la riscossione delle tasse';

  @override
  String get fundExchangeWarningTactic4 =>
      'Ti chiedono di inviare Bitcoin ad un loro indirizzo';

  @override
  String get fundExchangeWarningTactic5 =>
      'Ti chiedono di inviare Bitcoin su un\'altra piattaforma';

  @override
  String get fundExchangeWarningTactic6 =>
      'Vogliono che tu condivida lo schermo con loro';

  @override
  String get fundExchangeWarningTactic7 =>
      'Ti dicono di non preoccuparti di questo avvertimento';

  @override
  String get fundExchangeWarningTactic8 =>
      'Ti mettono fretta per farti agire subito';

  @override
  String get fundExchangeWarningConfirmation =>
      'Confermo che non mi viene chiesto di comprare Bitcoin da qualcun altro.';

  @override
  String get fundExchangeContinueButton => 'Continua';

  @override
  String get fundExchangeScamConsentError =>
      'Impossibile registrare il tuo consenso. Riprova.';

  @override
  String get fundExchangeDoneButton => 'Fatto';

  @override
  String get fundExchangeJurisdictionCanada => '🇨🇦 Canada';

  @override
  String get fundExchangeJurisdictionEurope => '🇪🇺 Europa (SEPA)';

  @override
  String get fundExchangeJurisdictionMexico => '🇲🇽 Messico';

  @override
  String get fundExchangeJurisdictionCostaRica => '🇨🇷 Costa Costa Rica';

  @override
  String get fundExchangeJurisdictionArgentina => '🇦🇷 Argentina';

  @override
  String get fundExchangeJurisdictionColombia => '🇨🇴 Colombia';

  @override
  String get fundExchangeMethodEmailETransfer => 'Email E-Transfer';

  @override
  String get fundExchangeMethodEmailETransferSubtitle =>
      'Il metodo più semplice e veloce (istantaneo)';

  @override
  String get fundExchangeMethodBankTransferWire =>
      'Trasferimento bancario (Wire o EFT)';

  @override
  String get fundExchangeMethodBankTransferWireSubtitle =>
      'L\'opzione migliore e più affidabile per importi elevati (in giornata o il giorno successivo)';

  @override
  String get fundExchangeMethodOnlineBillPayment => 'Pagamento bollette online';

  @override
  String get fundExchangeMethodOnlineBillPaymentSubtitle =>
      'L\'opzione più lenta, ma può essere fatto tramite online banking (3-4 giorni lavorativi)';

  @override
  String get fundExchangeMethodCanadaPost =>
      'In persona in contanti o addebito al Canada Post';

  @override
  String get fundExchangeMethodCanadaPostSubtitle =>
      'Meglio per chi preferisce pagare di persona';

  @override
  String get fundExchangeMethodInstantSepa => 'SEPA istantaneo e ordinario';

  @override
  String get fundExchangeMethodInstantSepaSubtitle =>
      'Più veloce - Solo per operazioni inferiori a €30.000';

  @override
  String get fundExchangeMethodRegularSepa => 'SEPA ordinario';

  @override
  String get fundExchangeMethodRegularSepaSubtitle =>
      'Solo per operazioni superiori a €30.000';

  @override
  String get fundExchangeBankTransferWireTitle => 'Bonifico bancario';

  @override
  String get fundExchangeBankTransferWireDescription =>
      'Invia un bonifico dal tuo conto utilizzando le coordinate di Bull Bitcoin fornite di seguito. La tua banca potrebbe richiedere solo alcune di queste informazioni.';

  @override
  String get fundExchangeBankTransferWireTimeframe =>
      'Tutti i fondi che invii verranno aggiunti al tuo Bull Bitcoin entro 1-2 giorni lavorativi.';

  @override
  String get fundExchangeLabelBeneficiaryName => 'Nome beneficiario';

  @override
  String get fundExchangeHelpBeneficiaryName =>
      'Usa il nostro nome ufficiale. Non usare \"Bull Bitcoin\".';

  @override
  String get fundExchangeLabelTransferCode =>
      'Codice di trasferimento (aggiungilo come causale o descrizione del pagamento)';

  @override
  String get fundExchangeHelpTransferCode =>
      'Aggiungi questo come motivo per il trasferimento';

  @override
  String get fundExchangeInfoTransferCode =>
      'È necessario aggiungere il codice di trasferimento come \"causale\" o \"motivo\" quando si effettua il pagamento.';

  @override
  String get fundExchangeLabelBankAccountDetails => 'Dati del conto bancario';

  @override
  String get fundExchangeLabelSwiftCode => 'Codice SWIFT';

  @override
  String get fundExchangeLabelInstitutionNumber => 'Numero dell\'istituto';

  @override
  String get fundExchangeLabelTransitNumber => 'Numero di transito';

  @override
  String get fundExchangeLabelRoutingNumber => 'Routing number (ABA)';

  @override
  String get fundExchangeLabelBeneficiaryAddress =>
      'Indirizzo del beneficiario';

  @override
  String get fundExchangeLabelBankName => 'Nome della banca';

  @override
  String get fundExchangeLabelBankAddress => 'Indirizzo della nostra banca';

  @override
  String get fundExchangeETransferTitle => 'Dettagli E-Transfer';

  @override
  String get fundExchangeETransferDescription =>
      'Qualsiasi importo che invii dalla tua banca via Email E-Transfer utilizzando le informazioni qui sotto verrà accreditato sul tuo conto Bull Bitcoin in pochi minuti.';

  @override
  String get fundExchangeETransferLabelBeneficiaryName =>
      'Utilizzare questo come nome beneficiario E-transfer';

  @override
  String get fundExchangeETransferLabelEmail =>
      'Invia l\'E-transfer a questa e-mail';

  @override
  String get fundExchangeETransferLabelSecretQuestion => 'Domanda segreta';

  @override
  String get fundExchangeETransferLabelSecretAnswer => 'Risposta segreta';

  @override
  String get fundExchangeOnlineBillPaymentTitle => 'Pagamento bollette online';

  @override
  String get fundExchangeOnlineBillPaymentDescription =>
      'Qualsiasi importo che invii con la funzione di pagamento bollette online della tua banca, usando i dati qui sotto, verrà accreditato sul saldo del tuo conto Bull Bitcoin entro 3-4 giorni lavorativi.';

  @override
  String get fundExchangeOnlineBillPaymentLabelBillerName =>
      'Cerca questo nome nell\'elenco dei fornitori della tua banca';

  @override
  String get fundExchangeOnlineBillPaymentHelpBillerName =>
      'Aggiungi questa società come beneficiario - è il processore di pagamento di Bull Bitcoin';

  @override
  String get fundExchangeCanadaPostTitle =>
      'In persona in contanti o addebito al Canada Post';

  @override
  String get fundExchangeCanadaPostStep1 =>
      '1. Vai a qualsiasi Canada Post posizione';

  @override
  String get fundExchangeCanadaPostStep2 =>
      '2. Chiedi al cassiere di scansionare il codice QR \"Loadhub\"';

  @override
  String get fundExchangeCanadaPostStep3 =>
      '3. Dì al cassiere l\'importo che desideri caricare';

  @override
  String get fundExchangeCanadaPostStep4 =>
      '4. Il cassiere chiederà di vedere un pezzo di ID rilasciato dal governo e verificare che il nome sul tuo ID corrisponda al tuo conto Bull Bitcoin';

  @override
  String get fundExchangeCanadaPostStep5 =>
      '5. Pagamento con contanti o carta di debito';

  @override
  String get fundExchangeCanadaPostStep6 =>
      '6. Il cassiere vi darà una ricevuta, tenerla come prova di pagamento';

  @override
  String get fundExchangeCanadaPostStep7 =>
      '7. I fondi saranno aggiunti al saldo del tuo conto Bull Bitcoin entro 30 minuti';

  @override
  String get fundExchangeCanadaPostQrCodeLabel => 'Loadhub Codice QR';

  @override
  String get fundExchangeSepaTitle => 'Bonifico SEPA';

  @override
  String get fundExchangeSepaDescription =>
      'Invia un bonifico SEPA dal tuo conto bancario utilizzando i dettagli qui sotto ';

  @override
  String get fundExchangeSepaDescriptionExactly => 'esattamente.';

  @override
  String get fundExchangeInstantSepaInfo =>
      'Usa questa opzione solo per operazioni inferiori a €30.000. Per importi maggiori, usa l\'opzione SEPA ordinario.';

  @override
  String get fundExchangeRegularSepaInfo =>
      'Usa questa opzione solo per operazioni superiori a €30.000. Per importi minori, usa l\'opzione SEPA istantaneo.';

  @override
  String get fundExchangeLabelIban => 'IBAN';

  @override
  String get fundExchangeLabelBicCode => 'Codice BIC';

  @override
  String get fundExchangeLabelBankAccountCountry => 'Paese';

  @override
  String get fundExchangeInfoBankCountryUk =>
      'La nostra banca ha sede nel Regno Unito.';

  @override
  String get fundExchangeInfoBeneficiaryNameLeonod =>
      'Il nome del beneficiario deve essere LEONOD. Se scrivi qualcos\'altro, il pagamento verrà respinto.';

  @override
  String get fundExchangeInfoPaymentDescription =>
      'Nella causale o descrizione del pagamento, aggiungi il codice di trasferimento.';

  @override
  String get fundExchangeHelpBeneficiaryAddress =>
      'Il nostro indirizzo ufficiale, se richiesto dalla tua banca';

  @override
  String get fundExchangeLabelRecipientName => 'Nome destinatario';

  @override
  String get fundExchangeLabelBankCountry => 'Paese';

  @override
  String get fundExchangeLabelRecipientAddress => 'Indirizzo del destinatario';

  @override
  String get fundExchangeSpeiTitle => 'Trasferimento SPEI';

  @override
  String get fundExchangeSpeiDescription =>
      'Trasferire fondi utilizzando il CLABE';

  @override
  String get fundExchangeSpeiInfo =>
      'Effettua un deposito utilizzando il trasferimento SPEI (instante).';

  @override
  String get fundExchangeLabelClabe => 'CLABE';

  @override
  String get fundExchangeLabelMemo => 'Memo';

  @override
  String get fundExchangeSinpeTitle => 'Trasferimento SINPE';

  @override
  String get fundExchangeSinpeDescription =>
      'Colonne di trasferimento utilizzando SINPE';

  @override
  String get fundExchangeCrIbanCrcTitle => 'Trasferimento bancario (CRC)';

  @override
  String get fundExchangeCrIbanUsdTitle => 'Trasferimento bancario (USD)';

  @override
  String get fundExchangeArsBankTransferTitle => 'Trasferimento bancario';

  @override
  String get fundExchangeArsBankTransferDescription =>
      'Invia un bonifico bancario dal tuo conto bancario utilizzando i dettagli bancari esatti in Argentina qui sotto.';

  @override
  String get fundExchangeLabelRecipientNameArs => 'Nome del destinatario';

  @override
  String get fundExchangeLabelCvu => 'CVU';

  @override
  String get fundExchangeErrorLoadingDetails =>
      'Impossibile caricare i dettagli di pagamento in questo momento. Torna indietro e riprova, scegli un altro metodo di pagamento o riprova più tardi.';

  @override
  String get fundExchangeErrorTitleOrdPo404 =>
      'Opzione di pagamento non disponibile';

  @override
  String get fundExchangeErrorOrdPo404 =>
      'Nessuna opzione di pagamento disponibile';

  @override
  String get fundExchangeErrorTitleRcpPo404 =>
      'Opzione di pagamento non disponibile';

  @override
  String get fundExchangeErrorRcpPo404 =>
      'Non hai i permessi necessari per accedere a questa opzione di deposito. Il tuo livello KYC è insufficiente o questa opzione non è disponibile per il tuo account';

  @override
  String get fundExchangeErrorTitleRcpPosinpe404 => 'SINPE non disponibile';

  @override
  String get fundExchangeErrorRcpPosinpe404 =>
      'Per accedere a questa opzione di deposito, il tuo numero di telefono deve essere registrato nella rete SINPE in Costa Rica.';

  @override
  String get fundExchangeErrorTitleOrdKyc400 => 'Requisiti KYC mancanti';

  @override
  String get fundExchangeErrorOrdKyc400 =>
      'Non hai i requisiti KYC per questa azione';

  @override
  String get fundExchangeErrorTitleOrdCop400 =>
      'Dati di finanziamento COP non validi';

  @override
  String get fundExchangeErrorOrdCop400 =>
      'Dati di richiesta non validi per il finanziamento COP';

  @override
  String get fundExchangeErrorOpeningPaymentLink =>
      'Non è stato possibile aprire il link di pagamento. Riprova.';

  @override
  String get fundExchangeErrorTitleOrdCsrcp400 =>
      'Pagamento virtuale non attivato';

  @override
  String get fundExchangeErrorOrdCsrcp400 =>
      'Attiva l\'opzione di pagamento virtuale per questo destinatario SEPA';

  @override
  String get fundExchangeErrorTitleRcp400 => 'Richiesta non valida';

  @override
  String get fundExchangeErrorRcp400 => 'Richiesta non valida';

  @override
  String get fundExchangeErrorFetchingBankCodes =>
      'Errore nel recupero dei codici bancari. Riprova più tardi.';

  @override
  String get fundExchangeSinpeDescriptionBold => 'sarà respinta.';

  @override
  String get fundExchangeSinpeAddedToBalance =>
      'Una volta inviato, il pagamento verrà aggiunto al saldo del tuo account.';

  @override
  String get fundExchangeSinpeLabelPhone => 'Invia a questo numero di telefono';

  @override
  String get fundExchangeSinpeLabelRecipientName => 'Nome destinatario';

  @override
  String get fundExchangeCrIbanCrcDescription =>
      'Invia un bonifico bancario dal tuo conto bancario utilizzando i dettagli qui sotto ';

  @override
  String get fundExchangeCrIbanCrcDescriptionBold => 'esattamente';

  @override
  String get fundExchangeCrIbanCrcDescriptionEnd =>
      '. I fondi saranno aggiunti al saldo del tuo conto.';

  @override
  String get fundExchangeCrIbanCrcLabelIban =>
      'Numero di conto IBAN (solo colonne)';

  @override
  String get fundExchangeCrIbanCrcLabelPaymentDescription =>
      'Descrizione del pagamento';

  @override
  String get fundExchangeCrIbanCrcPaymentDescriptionHelp =>
      'Il tuo codice di trasferimento.';

  @override
  String get fundExchangeCrIbanCrcTransferCodeWarning =>
      'È necessario aggiungere il codice di trasferimento come \"causale\" o \"motivo\" o \"descrizione\" quando si effettua il pagamento. Se si dimentica di includere questo codice, il pagamento può essere respinto.';

  @override
  String get fundExchangeCrIbanCrcLabelRecipientName => 'Nome destinatario';

  @override
  String get fundExchangeCrIbanCrcRecipientNameHelp =>
      'Usa il nostro nome ufficiale. Non usare \"Bull Bitcoin\".';

  @override
  String get fundExchangeCrIbanCrcLabelCedulaJuridica => 'Cédula Jurídica';

  @override
  String get fundExchangeCrIbanUsdDescription =>
      'Invia un bonifico bancario dal tuo conto bancario utilizzando i dettagli qui sotto ';

  @override
  String get fundExchangeCrIbanUsdDescriptionBold => 'esattamente';

  @override
  String get fundExchangeCrIbanUsdDescriptionEnd =>
      '. I fondi saranno aggiunti al saldo del tuo conto.';

  @override
  String get fundExchangeCrIbanUsdLabelIban =>
      'Numero conto IBAN (solo dollari USA)';

  @override
  String get fundExchangeCrIbanUsdLabelPaymentDescription =>
      'Descrizione del pagamento';

  @override
  String get fundExchangeCrIbanUsdPaymentDescriptionHelp =>
      'Il tuo codice di trasferimento.';

  @override
  String get fundExchangeCrIbanUsdTransferCodeWarning =>
      'È necessario aggiungere il codice di trasferimento come \"causale\" o \"motivo\" o \"descrizione\" quando si effettua il pagamento. Se si dimentica di includere questo codice, il pagamento può essere respinto.';

  @override
  String get fundExchangeCrIbanUsdLabelRecipientName => 'Nome destinatario';

  @override
  String get fundExchangeCrIbanUsdRecipientNameHelp =>
      'Usa il nostro nome ufficiale. Non usare \"Bull Bitcoin\".';

  @override
  String get fundExchangeCrIbanUsdLabelCedulaJuridica => 'Cédula Jurídica';

  @override
  String get fundExchangeCostaRicaMethodSinpeTitle => 'SINPE Móvil';

  @override
  String get fundExchangeCostaRicaMethodSinpeSubtitle =>
      'Colonne di trasferimento utilizzando SINPE';

  @override
  String get fundExchangeCostaRicaMethodIbanCrcTitle => 'IBAN Costa Rica (CRC)';

  @override
  String get fundExchangeCostaRicaMethodIbanCrcSubtitle =>
      'Fondi di trasferimento in Costa Rica Colón (CRC)';

  @override
  String get fundExchangeCostaRicaMethodIbanUsdTitle => 'IBAN Costa Rica (USD)';

  @override
  String get fundExchangeCostaRicaMethodIbanUsdSubtitle =>
      'Trasferimenti in dollari statunitensi (USD)';

  @override
  String get doneButton => 'Fatto';

  @override
  String get fundExchangeSpeiTransfer => 'Trasferimento SPEI';

  @override
  String get fundExchangeSpeiSubtitle =>
      'Trasferire fondi utilizzando il CLABE';

  @override
  String get fundExchangeBankTransfer => 'Trasferimento bancario';

  @override
  String get fundExchangeBankTransferSubtitle =>
      'Invia un bonifico bancario dal tuo conto bancario';

  @override
  String get fundExchangeCopDailyLimitWarning =>
      'Se superi il tuo limite giornaliero di transazione, la transazione fallirà. Dovrai contattare l\'assistenza clienti.';

  @override
  String get fundExchangeCopSenderName => 'Nome del mittente';

  @override
  String get fundExchangeCopIssuingBank => 'Banca emittente';

  @override
  String get fundExchangeCopSelectBankError => 'Seleziona una banca emittente';

  @override
  String get fundExchangeCopAmount => 'Importo';

  @override
  String get fundExchangeCopEnterAmountError => 'Inserisci un importo';

  @override
  String get fundExchangeCopValidAmountError => 'Inserisci un importo valido';

  @override
  String get fundExchangeCopGeneratePaymentLink => 'Genera link di pagamento';

  @override
  String get fundExchangeCopRedirectMessage =>
      'Verrai reindirizzato a una pagina esterna per effettuare il pagamento.';

  @override
  String get fundExchangeCopOpenPaymentLink => 'Apri link di pagamento';

  @override
  String get fundExchangeErrorNetwork =>
      'Controlla la connessione a Internet e riprova.';

  @override
  String get fundExchangeMethodConfidentialSepa => 'SEPA Riservato';

  @override
  String get fundExchangeMethodConfidentialSepaSubtitle =>
      'Un IBAN virtuale personale per depositare denaro in modo riservato';

  @override
  String get networkFeatureUnavailable =>
      'This feature is unavailable on the selected network.';

  @override
  String get fundExchangeOnlineBillPaymentLabelAccountNumber =>
      'Aggiungi questo come numero del conto';

  @override
  String get fundExchangeOnlineBillPaymentHelpAccountNumber =>
      'Questo numero di account unico è creato solo per voi';

  @override
  String get fundExchangeSinpeWarningNoBitcoin => 'Non mettere';

  @override
  String get fundExchangeSinpeWarningNoBitcoinDescription =>
      ' la parola \"Bitcoin\" o \"Crypto\" nella descrizione di pagamento. Questo blocca il pagamento.';

  @override
  String get exchangeCurrencyDropdownTitle => 'Seleziona la valuta';

  @override
  String get exchangeCurrencyDropdownValidation => 'Seleziona una valuta';

  @override
  String get exchangeAmountInputTitle => 'Inserire l\'importo';

  @override
  String get exchangeAmountInputValidationEmpty => 'Inserisci un importo';

  @override
  String get exchangeAmountInputValidationInvalid => 'Importo non valido';

  @override
  String get exchangeAmountInputValidationZero =>
      'L\'importo deve essere maggiore di zero';

  @override
  String get exchangeAmountInputValidationInsufficient => 'Saldo insufficiente';

  @override
  String get exchangeBitcoinWalletsBitcoinAddressLabel => 'Indirizzo Bitcoin';

  @override
  String get exchangeBitcoinWalletsLightningAddressLabel =>
      'Lightning (indirizzo LN)';

  @override
  String get exchangeBitcoinWalletsLiquidAddressLabel => 'Indirizzo Liquid';

  @override
  String get exchangeBitcoinWalletsEnterAddressHint => 'Inserisci l\'indirizzo';

  @override
  String get exchangeBitcoinWalletsSaveSuccess =>
      'Indirizzo del portafoglio salvato con successo';

  @override
  String get exchangeBitcoinWalletsDescription =>
      'Imposta gli indirizzi predefiniti dei portafogli a cui inviare automaticamente i Bitcoin acquistati.';

  @override
  String get exchangeDcaAddressLabelBitcoin => 'Indirizzo Bitcoin';

  @override
  String get exchangeDcaAddressLabelLightning => 'Indirizzo Lightning';

  @override
  String get exchangeDcaAddressLabelLiquid => 'Indirizzo Liquid';

  @override
  String get cancel => 'Annulla';

  @override
  String get delete => 'Elimina';

  @override
  String get save => 'Salva';

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
  String get settingsTermsOfServiceTitle => 'Termini di servizio';

  @override
  String get continueButton => 'Continua';

  @override
  String get autoBuyTitle => 'Acquisto Automatico';

  @override
  String get autoBuyDescription =>
      'Acquista automaticamente bitcoin ogni volta che depositi fondi sul tuo conto';

  @override
  String get autoBuyActivate => 'Attiva acquisto automatico';

  @override
  String get autoBuyDeactivate => 'Disattiva acquisto automatico';

  @override
  String get autoBuyCancelTitle => 'Annullare acquisto automatico?';

  @override
  String get autoBuyCancelMessage =>
      'Non acquisterai automaticamente bitcoin la prossima volta che depositerai fondi sul tuo conto.';

  @override
  String get autoBuyDeactivateConfirm => 'Sì, disattiva';

  @override
  String get autoBuyHowItWorks => 'Come funziona';

  @override
  String get autoBuyConnectWallet =>
      'Connetti il tuo portafoglio Bitcoin, Lightning o Liquid';

  @override
  String get autoBuyPurchaseCreated =>
      'Un acquisto di Bitcoin viene creato automaticamente ogni volta che depositi fondi sul tuo conto Bull Bitcoin.';

  @override
  String get autoBuyBitcoinSent =>
      'I Bitcoin vengono inviati direttamente al tuo portafoglio.';

  @override
  String get autoBuyRiskDisclaimer =>
      'L\'esecuzione dell\'ordine non può essere garantita. Ritardi o variazioni di prezzo tra il deposito e l\'acquisto possono modificare il tasso effettivo.';

  @override
  String get autoBuyGetStarted => 'Imposta l\'acquisto automatico';

  @override
  String get autoBuyConfirmTitle => 'Conferma acquisto automatico';

  @override
  String get autoBuyInfoMessage =>
      'Qualsiasi importo aggiunto al tuo account verrà convertito in Bitcoin al tasso di cambio corrente e inviato al tuo portafoglio.';

  @override
  String get autoBuyAccountUnavailableError =>
      'Il tuo account Bull Bitcoin non è disponibile. Riprova più tardi.';

  @override
  String get autoBuyWalletRequiredError =>
      'Aggiungi almeno un indirizzo predefinito Bitcoin, Lightning o Liquid.';

  @override
  String get autoBuyUpdateError =>
      'Non è stato possibile aggiornare l\'acquisto automatico. Riprova più tardi.';

  @override
  String get exchangeAuthLoginFailedTitle => 'Accesso non riuscito';

  @override
  String get exchangeAuthLoginFailedMessage =>
      'Si è verificato un errore. Prova ad accedere di nuovo.';

  @override
  String get exchangeAuthLoginFailedOkButton => 'OK';

  @override
  String get exchangeTradingUnavailable => 'Trading is unavailable.';
}
