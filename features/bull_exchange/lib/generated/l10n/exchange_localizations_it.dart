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

  @override
  String get settingsScreenTitle => 'Impostazioni';

  @override
  String get transactionHistoryTitle => 'Cronologia transazioni';

  @override
  String get exchangeHomeDepositButton => 'Deposito';

  @override
  String get exchangeHomeWithdrawButton => 'Prelievo';

  @override
  String get exchangeDcaUnableToGetConfig =>
      'Impossibile ottenere la configurazione del PAC';

  @override
  String get exchangeDcaDeactivateTitle => 'Disattiva l\'acquisto ricorrente';

  @override
  String get exchangeDcaActivateTitle => 'Attiva un acquisto ricorrente';

  @override
  String get exchangeDcaHideSettings => 'Nascondi le impostazioni';

  @override
  String get exchangeDcaViewSettings => 'Visualizza le impostazioni';

  @override
  String get exchangeDcaCancelDialogTitle =>
      'Cancella Bitcoin ricorrenti acquistare?';

  @override
  String get exchangeDcaCancelDialogMessage =>
      'Il tuo piano di acquisto ricorrente di Bitcoin si fermerà, e gli acquisti programmati termineranno. Per ricominciare, dovrai organizzare un nuovo piano.';

  @override
  String get exchangeDcaCancelDialogCancelButton => 'Annulla';

  @override
  String get exchangeDcaCancelDialogConfirmButton => 'Sì, disattivare';

  @override
  String get exchangeDcaFrequencyHour => 'ora';

  @override
  String get exchangeDcaFrequencyDay => 'giorno';

  @override
  String get exchangeDcaFrequencyWeek => 'settimana';

  @override
  String get exchangeDcaFrequencyMonth => 'mese';

  @override
  String get exchangeDcaNetworkBitcoin => 'Rete Bitcoin';

  @override
  String get exchangeDcaNetworkLightning => 'Rete Lightning';

  @override
  String get exchangeDcaNetworkLiquid => 'Rete Liquid';

  @override
  String exchangeDcaSummaryMessage(
    String amount,
    String frequency,
    String network,
  ) {
    return 'Stai acquistando $amount ogni $frequency via $network finché ci sono fondi sul tuo conto.';
  }

  @override
  String exchangeDcaAddressDisplay(String addressLabel, String address) {
    return '$addressLabel: $address';
  }

  @override
  String get exchangeKycLevelLight => 'Verifica di base';

  @override
  String get exchangeKycLevelLimited => 'Limitato';

  @override
  String get exchangeKycCardTitle => 'Completa la verifica KYC';

  @override
  String get exchangeKycCardSubtitle => 'Per rimuovere i limiti di transazione';

  @override
  String get homeActionBuy => 'Acquista';

  @override
  String get homeActionSell => 'Vendi';

  @override
  String get homeActionPay => 'Paga';

  @override
  String get homeActionTransfer => 'Swap';

  @override
  String get priceChartShowTooltip => 'Show price chart';

  @override
  String get recipientsSearchHint => 'Cerca destinatari per nome o etichetta';

  @override
  String get recipientsScreenTitle => 'Seleziona destinatario';

  @override
  String get recipientsScreenSubtitle => 'Chi riceverà il denaro?';

  @override
  String get recipientsTabNew => 'Nuovo destinatario';

  @override
  String get recipientsTabList => 'I miei destinatari fiat';

  @override
  String get recipientsPayoutMethod => 'Metodo di accredito';

  @override
  String get recipientsFilterByJurisdiction => 'Filtra per giurisdizione:';

  @override
  String get recipientsListEmpty => 'Nessun destinatario trovato.';

  @override
  String get recipientsContinue => 'Continua';

  @override
  String get recipientsJurisdictionAll => 'Tutte le giurisdizioni';

  @override
  String get recipientsJurisdictionCanada => '🇨🇦 Canada';

  @override
  String get recipientsJurisdictionEurope => '🇪🇺 Europa (SEPA)';

  @override
  String get recipientsJurisdictionMexico => '🇲🇽 Messico';

  @override
  String get recipientsJurisdictionCostaRica => '🇨🇷 Costa Rica';

  @override
  String get recipientsJurisdictionArgentina => '🇦🇷 Argentina';

  @override
  String get recipientsJurisdictionColombia => '🇨🇴 Colombia';

  @override
  String get recipientsTypeInteracEmail => 'Trasferimento di denaro via email';

  @override
  String get recipientsTypeBillPayment => 'Pagamento bollette';

  @override
  String get recipientsTypeBankTransfer => 'Bonifico bancario';

  @override
  String get recipientsTypeSepa => 'Bonifico SEPA';

  @override
  String get recipientsTypeSpeiClabe => 'SPEI CLABE';

  @override
  String get recipientsTypeSpeiSms => 'SPEI SMS';

  @override
  String get recipientsTypeSpeiCard => 'SPEI Carta';

  @override
  String get recipientsTypeSinpeIbanUsd => 'SINPE IBAN (USD)';

  @override
  String get recipientsTypeSinpeIbanCrc => 'SINPE IBAN (CRC)';

  @override
  String get recipientsTypeSinpeMovil => 'SINPE Móvil';

  @override
  String get recipientsTypeBankAccountAr => 'CBU/CVU Argentina';

  @override
  String get recipientsTypeBankAccountCo => 'Conto bancario COP';

  @override
  String get recipientsTypeNequi => 'Nequi';

  @override
  String get recipientsInfoEmail => 'Email';

  @override
  String get recipientsInfoPayee => 'Beneficiario';

  @override
  String get recipientsInfoAccount => 'Conto';

  @override
  String get recipientsInfoPhone => 'Telefono';

  @override
  String get recipientsInfoCard => 'Carta';

  @override
  String get recipientsInfoLabel => 'Etichetta';

  @override
  String get recipientsValidationFieldRequired =>
      'Questo campo non può essere vuoto';

  @override
  String get recipientsLabelOptional => 'Etichetta (facoltativo)';

  @override
  String get recipientsLabelHint =>
      'Inserisci un\'etichetta per questo destinatario';

  @override
  String get recipientsFieldName => 'Nome';

  @override
  String get recipientsFieldNameHint => 'Inserisci il nome del destinatario';

  @override
  String get recipientsFieldRecipientNameLabel => 'Nome del destinatario';

  @override
  String get recipientsFieldPhoneNumber => 'Numero di telefono';

  @override
  String get recipientsFieldPhoneNumberHint =>
      'Inserisci il numero di telefono';

  @override
  String get recipientsFieldSinpePhoneNumberHint =>
      '8 cifre senza prefisso internazionale';

  @override
  String get recipientsFieldDocumentType =>
      'Tipo di documento del destinatario';

  @override
  String get recipientsFieldDocumentNumberHint =>
      'Inserisci il numero di documento del destinatario';

  @override
  String get recipientsFieldOwnerName => 'Nome del titolare';

  @override
  String get recipientsFieldOwnerNameHint => 'Inserisci il nome del titolare';

  @override
  String get recipientsAccountOwnerQuestion => 'A chi appartiene questo conto?';

  @override
  String get recipientsAccountOwnerMine => 'È il mio conto';

  @override
  String get recipientsAccountOwnerSomeoneElse =>
      'È il conto di un\'altra persona';

  @override
  String get recipientsFieldIban => 'IBAN';

  @override
  String get recipientsFieldIbanHint => 'Inserisci l\'IBAN';

  @override
  String get recipientsFieldClabe => 'CLABE';

  @override
  String get recipientsFieldClabeHint => 'Inserisci il numero CLABE';

  @override
  String get recipientsFieldCvuCbu => 'CBU/CVU';

  @override
  String get recipientsFieldCvuCbuHint => 'Inserisci il numero CVU/CBU';

  @override
  String get recipientsFieldBankInstitution => 'Istituto bancario';

  @override
  String get recipientsFieldBankInstitutionPlaceholder =>
      'Seleziona un istituto bancario';

  @override
  String get recipientsValidationBankInstitution =>
      'Seleziona un istituto bancario';

  @override
  String get recipientsFieldAccountType => 'Tipo di conto';

  @override
  String get recipientsAccountTypeSavings => 'Risparmio';

  @override
  String get recipientsAccountTypeChecking => 'Corrente';

  @override
  String get recipientsFieldBankAccountNumber => 'Numero di conto bancario';

  @override
  String get recipientsFieldBankAccountNumberHint =>
      'Inserisci il numero di conto bancario';

  @override
  String get recipientsCopDocCc => 'Cédula de Ciudadanía';

  @override
  String get recipientsCopDocCe => 'Cédula de Extranjería';

  @override
  String get recipientsCopDocNit => 'Número de Identificación Tributaria';

  @override
  String get recipientsCopDocPassport => 'Passaporto';

  @override
  String get recipientsCopDocTi => 'Tarjeta de Identidad';

  @override
  String get recipientsCopDocRegistroCivil => 'Registro Civil';

  @override
  String get recipientsCopDocCcRecipientNumber =>
      'Numero di cédula del destinatario';

  @override
  String get recipientsCopDocCeRecipientNumber =>
      'Numero di cédula de extranjería del destinatario';

  @override
  String get recipientsCopDocNitRecipientNumber =>
      'Numero di codice fiscale del destinatario';

  @override
  String get recipientsCopDocPassportRecipientNumber =>
      'Numero di passaporto del destinatario';

  @override
  String get recipientsCopDocTiRecipientNumber =>
      'Numero della carta d\'identità del destinatario';

  @override
  String get recipientsCopDocRegistroCivilRecipientNumber =>
      'Numero di registro civile del destinatario';

  @override
  String get recipientsFieldDebitCard => 'Numero di carta di debito';

  @override
  String get recipientsFieldDebitCardHint =>
      'Inserisci il numero di carta di debito';

  @override
  String get recipientsFieldOwnerNameSinpeHint =>
      'Il nome del titolare apparirà qui';

  @override
  String get recipientsValidationSinpePhoneCountryCode =>
      'Rimuovi il prefisso internazionale (+506). Inserisci solo il numero a 8 cifre';

  @override
  String get recipientsValidationSinpePhoneInvalidChars =>
      'Usa solo cifre (no lettere o simboli)';

  @override
  String get recipientsValidationSinpePhoneTooShort =>
      'Inserisci tutte le 8 cifre del numero di telefono';

  @override
  String get recipientsValidationSinpeOwner => 'Verifica il numero di telefono';

  @override
  String get recipientsFieldEmailAddress => 'Indirizzo email';

  @override
  String get recipientsFieldEmailAddressHint => 'Inserisci l\'indirizzo email';

  @override
  String get recipientsFieldSecurityQuestion => 'Domanda di sicurezza';

  @override
  String get recipientsFieldSecurityQuestionHint =>
      'Inserisci la domanda di sicurezza (10-40 caratteri)';

  @override
  String get recipientsFieldSecurityAnswer => 'Risposta di sicurezza';

  @override
  String get recipientsFieldSecurityAnswerHint =>
      'Inserisci la risposta di sicurezza';

  @override
  String get recipientsValidationSecurityQuestionMin =>
      'La domanda di sicurezza deve avere almeno 10 caratteri';

  @override
  String recipientsCharCounter(int count) {
    return '$count/40 caratteri';
  }

  @override
  String get recipientsFieldInstitutionCode => 'Codice dell\'istituto';

  @override
  String get recipientsFieldInstitutionCodeHint =>
      'Inserisci il codice dell\'istituto';

  @override
  String get recipientsFieldInstitutionNumber => 'Numero dell\'istituto';

  @override
  String get recipientsFieldInstitutionNumberHint =>
      'Inserisci il numero dell\'istituto';

  @override
  String get recipientsFieldTransitNumber => 'Numero di transito';

  @override
  String get recipientsFieldTransitNumberHint =>
      'Inserisci il numero di transito';

  @override
  String get recipientsFieldAccountNumber => 'Numero di conto';

  @override
  String get recipientsFieldAccountNumberHint => 'Inserisci il numero di conto';

  @override
  String get recipientsFieldDefaultComment =>
      'Commento predefinito (facoltativo)';

  @override
  String get recipientsFieldDefaultCommentHint =>
      'Inserisci il commento predefinito';

  @override
  String get recipientsFieldCorporateAccount => 'Conto aziendale';

  @override
  String get recipientsFieldFirstName => 'Nome';

  @override
  String get recipientsFieldFirstNameHint => 'Inserisci il nome';

  @override
  String get recipientsFieldLastName => 'Cognome';

  @override
  String get recipientsFieldLastNameHint => 'Inserisci il cognome';

  @override
  String get recipientsFieldCorporateName => 'Ragione sociale';

  @override
  String get recipientsFieldCorporateNameHint => 'Inserisci la ragione sociale';

  @override
  String get recipientsFieldBillerName => 'Nome del fornitore';

  @override
  String get recipientsFieldBillerNameHint => 'Cerca e seleziona un fornitore';

  @override
  String get recipientsValidationBillerSearchMin =>
      'Inserisci 3 o più caratteri per cercare';

  @override
  String get recipientsValidationBillerSelect =>
      'Seleziona un fornitore dall\'elenco';

  @override
  String get recipientsFieldPayeeAccountNumber =>
      'Numero di conto del beneficiario';

  @override
  String get recipientsErrorLoadFailed =>
      'Non è stato possibile caricare i tuoi destinatari. Riprova.';

  @override
  String get recipientsErrorSaveFailed =>
      'Non è stato possibile salvare questo destinatario. Controlla i dati e riprova.';

  @override
  String get recipientsErrorSinpeLookupFailed =>
      'Non è stato possibile verificare questo numero di telefono. Controllalo e riprova.';

  @override
  String get recipientsErrorBillerSearchFailed =>
      'Non è stato possibile cercare i fornitori. Riprova.';

  @override
  String get recipientsErrorNetwork =>
      'Controlla la connessione a Internet e riprova.';

  @override
  String get recipientsListPullToRetry =>
      'Trascina verso il basso per riprovare.';

  @override
  String get recipientsErrorSavedButNotSelected =>
      'Questo destinatario è stato salvato, ma non è stato possibile continuare. Lo trovi nella tua lista.';

  @override
  String get recipientsTypeConfidentialSepa => 'SEPA Riservato';

  @override
  String get recipientsErrorVirtualIbanNotAvailable =>
      'Non hai i permessi necessari per accedere a questa opzione di deposito. Il tuo KYC è insufficiente o questa opzione non è disponibile per il tuo account';

  @override
  String get recipientsErrorEuResidencyRequired =>
      'Devi essere residente nell\'Unione Europea per attivare SEPA Riservato.';

  @override
  String get recipientsConfidentialSepaActivatingTitle =>
      'Attivazione del destinatario';

  @override
  String get recipientsConfidentialSepaActivatingDescription =>
      'Il tuo destinatario è in fase di attivazione per SEPA Riservato. L\'operazione può richiedere alcuni minuti.';

  @override
  String get recipientsConfidentialSepaNotActivatedTitle =>
      'Destinatario non attivato per SEPA Riservato';

  @override
  String get recipientsConfidentialSepaNotActivatedDescription =>
      'Questo destinatario non è ancora attivato per SEPA Riservato. Lo stiamo attivando ora. L\'operazione può richiedere alcuni minuti. Nel frattempo puoi usare SEPA Istantaneo e Ordinario.';

  @override
  String get recipientsConfidentialSepaActivatedTitle =>
      'Destinatario attivato';

  @override
  String get recipientsConfidentialSepaActivatedDescription =>
      'Il tuo destinatario è ora attivo per SEPA Riservato.';

  @override
  String get recipientsConfidentialSepaUseRegularSepa =>
      'Usa invece SEPA istantaneo e ordinario';

  @override
  String get recipientsReturnHome => 'Torna alla home';

  @override
  String get recipientsVirtualIbanIntroTitle => 'Attivare SEPA Riservato?';

  @override
  String get recipientsVirtualIbanNewBadge => 'Nuovo';

  @override
  String get recipientsVirtualIbanIntroDescription =>
      'Deposita fondi sul tuo conto in modo riservato usando un IBAN virtuale personale a tuo nome. È gratuito.';

  @override
  String get recipientsVirtualIbanIntroSelfTransfer =>
      'Quando invii fondi a Bull Bitcoin dalla tua banca, appare come un trasferimento a te stesso.';

  @override
  String get recipientsVirtualIbanIntroNoTransferCode =>
      'Nessun codice di trasferimento richiesto.';

  @override
  String get recipientsVirtualIbanNameWarningTitle =>
      'Importante: Corrispondenza dei nomi richiesta';

  @override
  String get recipientsVirtualIbanNameWarningDescription =>
      'Il nome del conto bancario deve corrispondere esattamente al nome del tuo IBAN virtuale Bull Bitcoin, altrimenti il trasferimento verrà restituito automaticamente. I nomi non corrispondono? Contatta il supporto.';

  @override
  String get recipientsVirtualIbanAccountOwnerName =>
      'Nome del Titolare del Conto';

  @override
  String get recipientsVirtualIbanNameConfirmation =>
      'Confermo che il nome corrisponde al/ai mio/miei conto/i bancario/i';

  @override
  String get recipientsVirtualIbanActivate => 'Attiva SEPA Riservato';

  @override
  String get recipientsVirtualIbanActivatingTitle =>
      'Attivazione SEPA Riservato...';

  @override
  String get recipientsVirtualIbanActivatingDescription =>
      'Creazione del tuo IBAN virtuale in corso. Potrebbero volerci alcuni minuti.';

  @override
  String get recipientsVirtualIbanActivatedTitle => 'SEPA Riservato Attivato';

  @override
  String get recipientsVirtualIbanActivatedDescription =>
      'Ora puoi usare il tuo IBAN virtuale personale per prelevare denaro in modo privato.';

  @override
  String get recipientsVirtualIbanCopied => 'Copiato negli appunti';

  @override
  String get recipientsVirtualIbanDone => 'Fatto';

  @override
  String get recipientsVirtualIbanRecipientName => 'Nome destinatario';

  @override
  String get recipientsVirtualIbanIbanLabel => 'Numero di conto IBAN virtuale';

  @override
  String get recipientsVirtualIbanCountry => 'Paese';

  @override
  String get recipientsVirtualIbanBic => 'Codice BIC';

  @override
  String get recipientsVirtualIbanActivatedFundingDescription =>
      'Ora puoi usare il tuo IBAN virtuale personale per depositare denaro in modo privato.';

  @override
  String get recipientsVirtualIbanShowDetails =>
      'Mostra i dettagli del mio IBAN virtuale';

  @override
  String get recipientsVirtualIbanDetailsDescription =>
      'Deposita sul tuo conto in modo riservato utilizzando un IBAN virtuale personale a tuo nome. Il deposito apparirà come un pagamento a te stesso, senza codice di trasferimento richiesto.';

  @override
  String get recipientsVirtualIbanBankAddress => 'Indirizzo della banca';

  @override
  String get recipientsVirtualIbanBankAddressHelp =>
      'L\'indirizzo ufficiale della banca, nel caso sia richiesto dalla tua banca.';

  @override
  String get recipientsConfidentialSepaNameMustMatchHint =>
      'I nomi devono corrispondere tra la tua banca e l\'IBAN virtuale oppure i trasferimenti verranno restituiti automaticamente.';

  @override
  String get recipientsFieldBankAccountIban =>
      'Numero di conto bancario (IBAN)';

  @override
  String get recipientsTypeConfidentialSepaDescription =>
      'I prelievi appaiono come un trasferimento a sé stessi con il nome del proprio conto';

  @override
  String get withdrawAmountTitle => 'Preleva valuta fiat';

  @override
  String get withdrawAmountContinue => 'Continua';

  @override
  String get withdrawConfirmTitle => 'Conferma il prelievo';

  @override
  String get withdrawConfirmRecipientName => 'Nome destinatario';

  @override
  String get withdrawConfirmAmount => 'Importo';

  @override
  String get withdrawConfirmEmail => 'Email';

  @override
  String get withdrawConfirmPayee => 'Beneficiario';

  @override
  String get withdrawConfirmAccount => 'Account';

  @override
  String get withdrawConfirmIban => 'IBAN';

  @override
  String get withdrawConfirmClabe => 'CLABE';

  @override
  String get withdrawConfirmPhone => 'Telefono';

  @override
  String get withdrawConfirmCard => 'Carta';

  @override
  String get withdrawConfirmButton => 'Conferma il prelievo';

  @override
  String get withdrawSuccessTitle => 'Prelievo avviato';

  @override
  String get withdrawSuccessOrderDetails => 'Dettagli dell\'ordine';

  @override
  String get withdrawConfirmBankAccount => 'Conto bancario';

  @override
  String get withdrawOwnershipQuestion => 'A chi appartiene questo conto?';

  @override
  String get withdrawOwnershipMyAccount => 'Questo è il mio conto';

  @override
  String get withdrawOwnershipOtherAccount =>
      'Questo è il conto di qualcun altro';

  @override
  String get withdrawUnauthenticatedError =>
      'Non sei autenticato. Accedi per continuare.';

  @override
  String withdrawBelowMinAmountError(String amount, String currency) {
    return 'L\'importo minimo è $amount $currency';
  }

  @override
  String withdrawAboveMaxAmountError(String amount, String currency) {
    return 'L\'importo massimo è $amount $currency';
  }

  @override
  String get withdrawInteracSecurityDetailsTitle =>
      'Dati di sicurezza del trasferimento';

  @override
  String get withdrawInteracSaveAsDefault =>
      'Salva questi dati come predefiniti';

  @override
  String get withdrawInteracSecurityQuestionLengthError =>
      'La domanda di sicurezza deve contenere 3–40 caratteri';

  @override
  String get withdrawInteracSecurityAnswerLengthError =>
      'La risposta di sicurezza deve contenere 3–40 caratteri';

  @override
  String get withdrawInteracSecurityAnswerFormatError =>
      'Usa lettere, numeri o trattini senza spazi';

  @override
  String get withdrawUnexpectedError =>
      'Il tuo prelievo non è stato completato al momento. Riprova o contatta l\'assistenza.';

  @override
  String get withdrawConfidentialSepaNotActivatedError =>
      'Attiva l\'opzione di pagamento riservato per questo destinatario SEPA.';

  @override
  String get limitOrdersTitle => 'Ordini limite';

  @override
  String get limitOrdersActiveTitle => 'Ordini limite attivi';

  @override
  String get limitOrdersCreateNew => 'Crea nuovo';

  @override
  String get limitOrdersMaximumActiveHint =>
      'Annulla un ordine attivo prima di crearne un altro.';

  @override
  String limitOrdersBuyAt(String price) {
    return 'Acquista a $price';
  }

  @override
  String get limitOrdersCancelAll => 'Annulla tutti';

  @override
  String get limitOrdersCancelAllTitle =>
      'Annullare tutti gli ordini limite attivi?';

  @override
  String get limitOrdersCancelAllMessage =>
      'L\'operazione è definitiva: dopo l\'annullamento nessuno di questi ordini verrà eseguito.';

  @override
  String get limitOrdersDialogConfirm => 'Conferma';

  @override
  String get limitOrdersDone => 'Fatto';

  @override
  String get limitOrdersTargetPrice => 'Prezzo obiettivo';

  @override
  String get limitOrdersFiatAmount => 'Importo';

  @override
  String get limitOrdersEstimatedBuyPrice => 'Prezzo di acquisto stimato';

  @override
  String get limitOrderDetailsTitle => 'Dettagli dell\'ordine limite';

  @override
  String get limitOrderDetailsStatus => 'Stato';

  @override
  String get limitOrderDetailsNumber => 'Numero d\'ordine';

  @override
  String get limitOrderDetailsAddress => 'Indirizzo di destinazione';

  @override
  String get limitOrderDetailsCreated => 'Data di creazione';

  @override
  String get limitOrderDetailsExpires => 'Data di scadenza';

  @override
  String get limitOrderCancel => 'Annulla l\'ordine limite';

  @override
  String get limitOrderCancelTitle => 'Annullare questo ordine limite?';

  @override
  String get limitOrderCancelMessage =>
      'L\'annullamento è definitivo e l\'ordine non verrà più eseguito.';

  @override
  String get limitOrderStatusActive => 'Attivo';

  @override
  String get limitOrderStatusExecuted => 'Eseguito';

  @override
  String get limitOrderStatusCancelled => 'Annullato';

  @override
  String get limitOrderStatusExpired => 'Scaduto';

  @override
  String get limitOrderStatusFailed => 'Fallito';

  @override
  String get limitOrdersAccountUnavailableError =>
      'Non è stato possibile caricare il tuo conto o i saldi Bull Bitcoin. Riprova.';

  @override
  String get limitOrderNotFoundError =>
      'Impossibile trovare questo ordine limite.';

  @override
  String get limitOrdersLoadError =>
      'Impossibile caricare gli ordini limite. Riprova.';

  @override
  String get limitOrderCancellationError =>
      'Impossibile annullare l\'ordine limite. Riprova.';

  @override
  String get limitOrderDetailsEstimatedBitcoin => 'Bitcoin previsti';

  @override
  String get limitOrdersMaximumActiveError =>
      'Hai già cinque ordini limite attivi. Annullane uno prima di crearne un altro.';

  @override
  String get limitOrderInvalidAddressError =>
      'L\'indirizzo di destinazione selezionato non è valido.';

  @override
  String get limitOrderCreationError =>
      'Impossibile creare l\'ordine limite. Riprova.';

  @override
  String get exchangeSettingsLogOutTitle => 'Esci';

  @override
  String get logoutConfirmationTitle => 'Conferma disconnessione';

  @override
  String get logoutConfirmationDescription =>
      'Vuoi davvero uscire dal tuo account Bull Bitcoin? Dovrai accedere di nuovo per usare le funzioni dell\'exchange.';

  @override
  String get logoutConfirmationCancel => 'Annulla';

  @override
  String get logoutConfirmationLogout => 'Disconnetti';

  @override
  String get exchangeSettingsDeleteAccountTitle => 'Elimina account';

  @override
  String get deleteAccountConfirmationTitle => 'Elimina account';

  @override
  String get deleteAccountConfirmationDescription =>
      'Verrà inviata una richiesta di eliminazione dell\'account al nostro team di supporto. Il tuo account sarà eliminato entro 5 giorni lavorativi.';

  @override
  String get deleteAccountConfirmationCancel => 'Annulla';

  @override
  String get deleteAccountConfirmationDelete => 'Elimina account';

  @override
  String get deleteAccountSuccessTitle =>
      'Eliminazione dell\'account richiesta';

  @override
  String get deleteAccountSuccessDescription =>
      'La richiesta di eliminazione del tuo account è stata inviata. Verrà elaborata entro 5 giorni lavorativi.';

  @override
  String get deleteAccountSuccessClose => 'Chiudi';

  @override
  String get buyEnterAmount => 'Inserisci l\'importo';

  @override
  String get buyPaymentMethod => 'Metodo di pagamento';

  @override
  String get buyMax => 'Max';

  @override
  String get buySelectWallet => 'Seleziona il portafoglio';

  @override
  String get buyEnterBitcoinAddress => 'Inserisci l\'indirizzo bitcoin';

  @override
  String get buyBitcoinAddressHint => 'BC1QYL7J673H...6Y6ALV70M0';

  @override
  String get buyConfirmPurchase => 'Conferma l\'acquisto';

  @override
  String buyYouBought(String amount, String fiatAmount) {
    return 'Hai comprato $amount con $fiatAmount';
  }

  @override
  String get buyPayoutWillBeSentIn => 'Il pagamento verrà inviato tra ';

  @override
  String get buyViewDetails => 'Visualizza dettagli';

  @override
  String get buyAccelerateTransaction => 'Accelera la transazione';

  @override
  String get buyGetConfirmedFaster => 'Ottieni una conferma più rapida';

  @override
  String get buyConfirmExpressWithdrawal => 'Conferma l\'invio rapido';

  @override
  String get buyNetworkFeeExplanation =>
      'Le commissioni di rete Bitcoin saranno detratte dall\'importo che ricevi e raccolti dai minatori Bitcoin';

  @override
  String get buyNetworkFees => 'Commissioni di rete';

  @override
  String get buyEstimatedFeeValue => 'Stima delle commissioni';

  @override
  String get buyNetworkFeeRate => 'Tasso di commissione di rete';

  @override
  String get buyConfirmationTime => 'Tempi di conferma';

  @override
  String get buyConfirmationTimeValue => '10 minuti';

  @override
  String get buyWaitForFreeWithdrawal => 'Attendi l\'invio gratuito';

  @override
  String get buyConfirmExpress => 'Conferma invio rapido';

  @override
  String get buyBitcoinSent => 'Bitcoin inviati!';

  @override
  String get buyThatWasFast => 'È stato veloce, vero?';

  @override
  String get globalDefaultBitcoinWalletLabel => 'Bitcoin sicuri';

  @override
  String get globalDefaultLiquidWalletLabel => 'Pagamenti istantanei';

  @override
  String get dcaSuccessTitle => 'L\'acquisto ricorrente è attivo!';

  @override
  String dcaSuccessMessageHourly(String amount) {
    return 'Comprerai $amount ogni ora';
  }

  @override
  String dcaSuccessMessageDaily(String amount) {
    return 'Comprerai $amount ogni giorno';
  }

  @override
  String dcaSuccessMessageWeekly(String amount) {
    return 'Comprerai $amount ogni settimana';
  }

  @override
  String dcaSuccessMessageMonthly(String amount) {
    return 'Comprerai $amount ogni mese';
  }

  @override
  String get dcaBackToHomeButton => 'Torna alla home';

  @override
  String get dcaChooseWalletTitle => 'Scegli il portafoglio Bitcoin';

  @override
  String get dcaWalletSelectionDescription =>
      'Gli acquisti di Bitcoin verranno effettuati automaticamente secondo questa pianificazione.';

  @override
  String get dcaNetworkValidationError => 'Seleziona una rete';

  @override
  String get dcaEnterLightningAddressLabel =>
      'Inserisci l\'indirizzo Lightning';

  @override
  String get dcaUseDefaultLightningAddress =>
      'Usa il mio indirizzo Lightning predefinito.';

  @override
  String get dcaWalletSelectionContinueButton => 'Continua';

  @override
  String get dcaSelectFrequencyLabel => 'Seleziona frequenza';

  @override
  String get dcaSelectWalletTypeLabel =>
      'Seleziona il tipo di portafoglio Bitcoin';

  @override
  String get dcaWalletTypeBitcoin => 'Bitcoin (BTC)';

  @override
  String get dcaWalletTypeLightning => 'Lightning Network (LN)';

  @override
  String get dcaWalletTypeLiquid => 'Liquid (L-BTC)';

  @override
  String get dcaWalletBitcoinSubtitle => 'Minimo 0,00';

  @override
  String get dcaWalletLightningSubtitle =>
      'Richiede portafoglio compatibile, massimo 0.25 BTC';

  @override
  String get dcaWalletLiquidSubtitle => 'Richiede portafoglio compatibile';

  @override
  String get dcaSetupTitle => 'Imposta acquisto ricorrente';

  @override
  String get dcaSetupInsufficientBalance => 'Saldo insufficiente';

  @override
  String get dcaSetupInsufficientBalanceMessage =>
      'Non hai abbastanza fondi per creare questo ordine.';

  @override
  String get dcaSetupFundAccount => 'Deposita fondi';

  @override
  String get dcaSetupScheduleMessage =>
      'Gli acquisti di Bitcoin verranno effettuati automaticamente secondo questa pianificazione.';

  @override
  String get dcaSetupFrequencyError => 'Seleziona una frequenza';

  @override
  String get dcaSetupContinue => 'Continua';

  @override
  String get dcaConfirmTitle => 'Conferma l\'acquisto ricorrente';

  @override
  String get dcaConfirmAutoMessage =>
      'Gli ordini di acquisto verranno effettuati automaticamente secondo queste impostazioni. Puoi disattivarli quando vuoi.';

  @override
  String get dcaConfirmFrequency => 'Frequenza';

  @override
  String get dcaConfirmFrequencyHourly => 'Ogni ora';

  @override
  String get dcaConfirmFrequencyDaily => 'Ogni giorno';

  @override
  String get dcaConfirmFrequencyWeekly => 'Ogni settimana';

  @override
  String get dcaConfirmFrequencyMonthly => 'Ogni mese';

  @override
  String get dcaConfirmAmount => 'Importo';

  @override
  String get dcaConfirmPaymentMethod => 'Metodo di pagamento';

  @override
  String dcaConfirmPaymentBalance(String currency) {
    return 'saldo $currency';
  }

  @override
  String get dcaConfirmOrderType => 'Tipo d\'ordine';

  @override
  String get dcaConfirmOrderTypeValue => 'Acquisto ricorrente';

  @override
  String get dcaConfirmNetwork => 'Rete';

  @override
  String get dcaConfirmNetworkBitcoin => 'Bitcoin';

  @override
  String get dcaConfirmNetworkLightning => 'Lightning';

  @override
  String get dcaConfirmNetworkLiquid => 'Liquid';

  @override
  String get dcaConfirmLightningAddress => 'Indirizzo Lightning';

  @override
  String get dcaConfirmContinue => 'Continua';

  @override
  String get buyInputTitle => 'Acquista Bitcoin';

  @override
  String get buyInputMinAmountError => 'Dovresti comprare almeno';

  @override
  String get buyInputMaxAmountError => 'Non puoi comprare più di';

  @override
  String get buyInputKycPending => 'Verifica KYC in attesa';

  @override
  String get buyInputKycMessage =>
      'È necessario completare l\'ID verifica prima';

  @override
  String get buyInputCompleteKyc => 'Completa la verifica KYC';

  @override
  String get buyInputInsufficientBalance => 'Saldo insufficiente';

  @override
  String get buyInputInsufficientBalanceMessage =>
      'Non hai abbastanza fondi per creare questo ordine.';

  @override
  String get buyInputFundAccount => 'Deposita fondi';

  @override
  String get buyInputContinue => 'Continua';

  @override
  String get buyConfirmTitle => 'Acquista Bitcoin';

  @override
  String get buyConfirmYouPay => 'Paghi';

  @override
  String get buyConfirmYouReceive => 'Riceverai';

  @override
  String get buyConfirmBitcoinPrice => 'Prezzo di Bitcoin';

  @override
  String get buyConfirmPayoutWallet => 'Portafoglio di destinazione';

  @override
  String get buyConfirmPayoutMethod => 'Metodo di accredito';

  @override
  String get buyPayoutMethodLiquid => 'L-BTC su Liquid';

  @override
  String get buyPayoutMethodBitcoin => 'Bitcoin on-chain';

  @override
  String get buyConfirmExternalWallet => 'Portafoglio Bitcoin esterno';

  @override
  String get buyConfirmAwaitingConfirmation => 'In attesa di conferma ';

  @override
  String get buyUnauthenticatedError =>
      'Non sei autenticato. Accedi per continuare.';

  @override
  String get buyBelowMinAmountError =>
      'Stai cercando di acquistare sotto la quantità minima.';

  @override
  String get buyAboveMaxAmountError =>
      'Stai cercando di acquistare sopra la quantità massima.';

  @override
  String get buyUnexpectedError =>
      'Non è stato possibile creare il tuo ordine in questo momento. Riprova o contatta l\'assistenza.';

  @override
  String get dcaAccountUnavailableError =>
      'Impossibile caricare il tuo account. Controlla la connessione, assicurati di aver effettuato l\'accesso e riprova.';

  @override
  String get dcaLightningAddressRequiredError =>
      'Inserisci un indirizzo Lightning per ricevere i tuoi acquisti.';

  @override
  String get dcaReceiveAddressError =>
      'Non è stato possibile preparare un indirizzo di ricezione nel tuo portafoglio. Riprova.';

  @override
  String get dcaOrderCreationError =>
      'Non è stato possibile creare l\'acquisto ricorrente. Riprova più tardi.';

  @override
  String get payjoinInProgress => 'Payjoin in corso';

  @override
  String get payjoinSucceeded => 'Payjoin riuscito';

  @override
  String get payjoinBuyRegularSend =>
      'Bitcoin inviati al tuo portafoglio con un invio normale';

  @override
  String get payjoinUseToggle => 'Usa Payjoin';

  @override
  String get limitOrdersLightningAddressHint => 'tu@dominio.com';

  @override
  String get exchangeQuoteUnavailableError =>
      'Non siamo riusciti a ottenere un prezzo aggiornato. Riprova, oppure torna indietro e crea un nuovo ordine.';

  @override
  String get buyQuoteExpiredError =>
      'Questo prezzo è scaduto. Ne stiamo caricando uno nuovo: controllalo prima di confermare.';

  @override
  String get sellTitle => 'Vendi Bitcoin';

  @override
  String get sellSelectWallet => 'Seleziona portafoglio';

  @override
  String get sellWhichWalletQuestion => 'Da quale portafoglio vuoi vendere?';

  @override
  String get sellExternalWallet => 'Portafoglio esterno';

  @override
  String get sellFromAnotherWallet => 'Vendere da un altro portafoglio Bitcoin';

  @override
  String get sellAboveMaxAmountError =>
      'Stai cercando di vendere sopra l\'importo massimo che può essere venduto con questo portafoglio.';

  @override
  String get sellBelowMinAmountError =>
      'Stai cercando di vendere sotto l\'importo minimo che può essere venduto con questo portafoglio.';

  @override
  String get sellInsufficientBalanceError =>
      'Saldo insufficiente nel portafoglio selezionato per completare questo ordine di vendita.';

  @override
  String get sellUnauthenticatedError =>
      'Non sei autenticato. Sei pregato di accedere per continuare.';

  @override
  String get sellOrderNotFoundError =>
      'L\'ordine di vendita non è stato trovato. Riprova.';

  @override
  String get sellOrderAlreadyConfirmedError =>
      'Questo ordine di vendita è già stato confermato.';

  @override
  String get sellSelectNetwork => 'Seleziona la rete';

  @override
  String get sellHowToPayInvoice => 'Come vuoi pagare questa fattura?';

  @override
  String get sellBitcoinOnChain => 'Bitcoin on-chain';

  @override
  String get sellLightningNetwork => 'Rete Lightning';

  @override
  String get sellLiquidNetwork => 'Rete Liquid';

  @override
  String get sellConfirmPayment => 'Conferma del pagamento';

  @override
  String get sellPriceWillRefreshIn => 'Il prezzo si aggiorna in ';

  @override
  String get sellOrderNumber => 'Numero d\'ordine';

  @override
  String get sellPayoutRecipient => 'Destinatario';

  @override
  String get sellCadBalance => 'Saldo CAD';

  @override
  String get sellCrcBalance => 'Saldo CRC';

  @override
  String get sellEurBalance => 'Saldo EUR';

  @override
  String get sellUsdBalance => 'Saldo USD';

  @override
  String get sellMxnBalance => 'Saldo MXN';

  @override
  String get sellArsBalance => 'ARS Balance';

  @override
  String get sellCopBalance => 'Saldo COP';

  @override
  String get sellPayinAmount => 'Importo da pagare';

  @override
  String get sellPayoutAmount => 'Importo da ricevere';

  @override
  String get sellExchangeRate => 'Tasso di cambio';

  @override
  String get sellPayFromWallet => 'Paga dal portafoglio';

  @override
  String get sellInstantPayments => 'Pagamenti istantanei';

  @override
  String get sellSecureBitcoinWallet => 'Portafoglio sicuro Bitcoin';

  @override
  String get sellFeePriority => 'Priorità';

  @override
  String get sellFastest => 'Più veloce';

  @override
  String get sellAdvancedSettings => 'Impostazioni avanzate';

  @override
  String get sellAdvancedOptions => 'Opzioni avanzate';

  @override
  String get sellReplaceByFeeActivated => 'Replace-By-Fee (RBF) attivato';

  @override
  String get sellSelectCoinsManually => 'Seleziona le monete manualmente';

  @override
  String get sellDone => 'Fatto';

  @override
  String get sellPleasePayInvoice => 'Paga questa fattura';

  @override
  String get sellBitcoinAmount => 'Importo in Bitcoin';

  @override
  String get sellCopyInvoice => 'Copia fattura';

  @override
  String get sellShowQrCode => 'Mostra il codice QR';

  @override
  String get sellQrCode => 'Codice QR QR';

  @override
  String get sellNoInvoiceData => 'Nessun dato di fattura disponibile';

  @override
  String get sellInProgress => 'Vendita in corso...';

  @override
  String get sellGoHome => 'Torna alla home';

  @override
  String get sellOrderCompleted => 'Ordine completato!';

  @override
  String get sellBalanceWillBeCredited =>
      'Il saldo del tuo conto verrà accreditato dopo che la tua transazione riceve 1 conferma in contanti.';

  @override
  String sellYouSold(String amount, String fiatAmount) {
    return 'Hai venduto $amount per $fiatAmount';
  }

  @override
  String get payTitle => 'Paga';

  @override
  String get payDescriptionLabel => 'Descrizione del pagamento (facoltativo)';

  @override
  String get payDescriptionHint => 'Aggiungi una nota a questo pagamento';

  @override
  String get payPaymentDescription => 'Descrizione del pagamento';

  @override
  String get payRecipientType => 'Tipo di destinatario';

  @override
  String get payRecipientName => 'Nome destinatario';

  @override
  String get payRecipientDetails => 'Dettagli importanti';

  @override
  String get payNoDetailsAvailable => 'Nessun dettaglio disponibile';

  @override
  String get paySelectWallet => 'Seleziona portafoglio';

  @override
  String get payExternalWallet => 'Portafoglio esterno';

  @override
  String payAboveMaxAmountError(String amount) {
    return 'L\'importo massimo che puoi pagare con questo portafoglio è $amount.';
  }

  @override
  String payBelowMinAmountError(String amount) {
    return 'L\'importo minimo che puoi pagare con questo portafoglio è $amount.';
  }

  @override
  String get payInsufficientBalanceError =>
      'Saldo insufficiente nel portafoglio selezionato per completare questo ordine di pagamento.';

  @override
  String get payUnauthenticatedError =>
      'Non sei autenticato. Accedi per continuare.';

  @override
  String get paySelectNetwork => 'Seleziona la rete';

  @override
  String get payHowToPayInvoice => 'Come vuoi pagare questa fattura?';

  @override
  String get payLightningNetwork => 'Rete Lightning';

  @override
  String get payLiquidNetwork => 'Rete Liquid';

  @override
  String get payConfirmPayment => 'Conferma pagamento';

  @override
  String get payOrderNumber => 'Numero d\'ordine';

  @override
  String get payPayinAmount => 'Importo da pagare';

  @override
  String get payPayoutAmount => 'Importo da ricevere';

  @override
  String get payExchangeRate => 'Tasso di cambio';

  @override
  String get payPayFromWallet => 'Paga dal portafoglio';

  @override
  String get payInstantPayments => 'Pagamenti istantanei';

  @override
  String get paySecureBitcoinWallet => 'Portafoglio sicuro Bitcoin';

  @override
  String get payFeePriority => 'Priorità (commissioni)';

  @override
  String get payFastest => 'Più veloce';

  @override
  String get payNetworkFees => 'Commissioni di rete';

  @override
  String get payAdvancedSettings => 'Impostazioni avanzate';

  @override
  String get payAdvancedOptions => 'Opzioni avanzate';

  @override
  String get paySelectCoinsManually => 'Seleziona le monete manualmente';

  @override
  String get payDone => 'Fatto';

  @override
  String get payContinue => 'Continua';

  @override
  String get payPleasePayInvoice => 'Paga questa fattura';

  @override
  String get payBitcoinAmount => 'Importo in Bitcoin';

  @override
  String get payBitcoinPrice => 'Prezzo di Bitcoin';

  @override
  String get payCopyInvoice => 'Copia fattura';

  @override
  String get payShowQrCode => 'Mostra il codice QR';

  @override
  String get payQrCode => 'Codice QR QR';

  @override
  String get payNoInvoiceData => 'Nessun dato di fattura disponibile';

  @override
  String get payInvalidState => 'Stato non valido';

  @override
  String get payViewDetails => 'Visualizza dettagli';

  @override
  String get paySinpeReceipt => 'Ricevuta SINPE';

  @override
  String get payCompleted => 'Pagamento completato!';

  @override
  String payCompletedDescriptionDetails(String fiatAmount, String recipient) {
    return 'Il pagamento di $fiatAmount a $recipient è stato completato.';
  }

  @override
  String get paySinpeEnviado => 'SINPE inviato!';

  @override
  String get payOrderDetails => 'Dettagli dell\'ordine';

  @override
  String get paySinpeMonto => 'Importo';

  @override
  String get paySinpeNumeroOrden => 'Numero d\'ordine';

  @override
  String get paySinpeNumeroComprobante => 'Numero di riferimento';

  @override
  String get paySinpeBeneficiario => 'Beneficiario';

  @override
  String get paySinpeOrigen => 'Origine';

  @override
  String get payNotAvailable => 'N/A';

  @override
  String get payBitcoinOnchain => 'Bitcoin on-chain';

  @override
  String get payPaymentInProgress => 'Pagamento in corso!';

  @override
  String payPaymentInProgressDescriptionDetails(
    String fiatAmount,
    String recipient,
  ) {
    return 'Il pagamento di $fiatAmount a $recipient verrà inviato quando la tua transazione avrà ricevuto 1 conferma on-chain.';
  }

  @override
  String payPaymentPayinConfirmedDescriptionDetails(
    String fiatAmount,
    String recipient,
  ) {
    return 'La tua transazione è confermata. Il pagamento di $fiatAmount a $recipient è in elaborazione.';
  }

  @override
  String get payPriceRefreshIn => 'Il prezzo si aggiorna in ';

  @override
  String get payWhichWallet => 'Da quale portafoglio vuoi pagare?';

  @override
  String get payExternalWalletDescription =>
      'Paga da un altro portafoglio Bitcoin';

  @override
  String get payRbfActivated => 'Replace-By-Fee (RBF) attivato';

  @override
  String get copyDialogButton => 'Copia';

  @override
  String get closeDialogButton => 'Chiudi';

  @override
  String get sellCompleteKYC => 'Completa il KYC';

  @override
  String get sellSendPaymentNetworkFees => 'Commissioni di rete';

  @override
  String get sellSendPaymentContinue => 'Continua';

  @override
  String get exchangeSendingPayment => 'Invio del pagamento in corso…';

  @override
  String get exchangePaymentSentRefreshingOrder =>
      'Pagamento inviato, aggiornamento dell\'ordine in corso…';

  @override
  String get sellBitcoinPriceLabel => 'Prezzo di Bitcoin';

  @override
  String get sellViewDetailsButton => 'Visualizza dettagli';

  @override
  String get sellKycPendingTitle => 'Verifica KYC in attesa';

  @override
  String get sellKycPendingDescription =>
      'Prima devi completare la verifica KYC.';

  @override
  String get sellLoadingGeneric => 'Caricamento...';

  @override
  String get viewerTapToCopy => 'Tocca per copiare';

  @override
  String get invoiceViewerTitle => 'Fattura';

  @override
  String get payjoinViaPayjoin => 'con Payjoin';

  @override
  String get payjoinViaRegularSend => 'con invio normale';

  @override
  String get sellDepositAddress => 'Indirizzo di deposito';

  @override
  String get payDepositAddress => 'Indirizzo di deposito';

  @override
  String get sellDepositAddressChangedError =>
      'L\'indirizzo di deposito di questo ordine è cambiato in modo imprevisto. Per sicurezza non pagare questo ordine: torna indietro e creane uno nuovo.';

  @override
  String get payDepositAddressChangedError =>
      'L\'indirizzo di deposito di questo ordine è cambiato in modo imprevisto. Per sicurezza non pagare questo ordine: torna indietro e creane uno nuovo.';

  @override
  String get sellUnexpectedError =>
      'Il tuo ordine di vendita non è stato completato al momento. Riprova o contatta l\'assistenza.';

  @override
  String get sellErrorFeeBelowRelayFloor =>
      'Commissione di rete troppo bassa. Scegli una commissione più alta.';

  @override
  String get sellErrorFeesUnavailable =>
      'Non è stato possibile caricare le commissioni di rete. Controlla la connessione e riprova.';

  @override
  String get payUnexpectedError =>
      'Impossibile completare il pagamento in questo momento. Riprova o contatta l\'assistenza.';

  @override
  String get payErrorFeeBelowRelayFloor =>
      'Commissione di rete troppo bassa. Scegli una commissione più alta.';

  @override
  String get payErrorFeesUnavailable =>
      'Impossibile caricare le commissioni di rete. Controlla la connessione e riprova.';

  @override
  String get withdrawRecipientsPrompt =>
      'Dove e come dobbiamo inviare il denaro?';

  @override
  String get copiedToClipboard => 'Copiato negli appunti';

  @override
  String get sellQuoteExpiredError =>
      'Questo prezzo è scaduto. Ne stiamo caricando uno nuovo: controllalo prima di confermare.';

  @override
  String get exchangePaymentSentPastDeadline =>
      'Pagamento inviato. L\'exchange segnala che la scadenza per pagare questo ordine è passata. Conserva l\'ID della transazione qui sotto e contatta l\'assistenza se l\'ordine non si aggiorna.';

  @override
  String get exchangePaymentSentLeave => 'Esci';

  @override
  String get payQuoteExpiredError =>
      'Questo prezzo è scaduto. Ne stiamo caricando uno nuovo: controllalo prima di confermare.';

  @override
  String get sellPayoutBalance => 'Aggiungi al saldo del mio account';

  @override
  String get sellPayoutSepaDescription =>
      'I prelievi appaiono come inviati da Leonod';

  @override
  String get sellPayoutTitle => 'Seleziona destinatario';

  @override
  String get sellPayoutNewBadge => 'NUOVO';

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
      'Non è stato possibile confermare che la transazione sia stata trasmessa. Controlla un block explorer prima di riprovare.';

  @override
  String get sendSelectedUtxosInsufficient =>
      'Gli UTXO selezionate non coprono l\'importo richiesto';

  @override
  String get selectAmountTitle => 'Seleziona l\'importo';

  @override
  String amountRequestedLabel(String amount) {
    return 'Quantità richiesta: $amount';
  }

  @override
  String get addressLabel => 'Indirizzo: ';

  @override
  String get typeLabel => 'Tipo: ';

  @override
  String get coinsKeychainReceive => 'Ricezione';

  @override
  String get coinsKeychainChange => 'Resto';

  @override
  String get limitOrdersIntroTitle => 'Apri un ordine limite';

  @override
  String get limitOrdersIntroDescription =>
      'Scegli un prezzo di bitcoin più basso e un importo da acquistare con il tuo saldo Bull Bitcoin.';

  @override
  String get limitOrdersIntroBulletPrice =>
      'Il tuo ordine resta attivo finché il prezzo indice non raggiunge l\'obiettivo.';

  @override
  String get limitOrdersIntroBulletBalance =>
      'Al momento dell\'esecuzione, l\'acquisto usa il saldo in valuta fiat selezionato.';

  @override
  String get limitOrdersIntroBulletExecution =>
      'I bitcoin vengono inviati al portafoglio predefinito che hai scelto.';

  @override
  String get limitOrdersTargetTitle => 'Scegli il prezzo obiettivo';

  @override
  String get limitOrdersPaymentMethod => 'Metodo di pagamento';

  @override
  String get limitOrdersCurrentPrice => 'Prezzo indice attuale';

  @override
  String get limitOrdersDiscount => 'Sconto rispetto al prezzo attuale';

  @override
  String get limitOrdersAmountTitle => 'Imposta l\'importo';

  @override
  String limitOrdersAvailableBalance(String amount) {
    return 'Saldo disponibile: $amount';
  }

  @override
  String limitOrdersEstimatedBitcoin(String amount) {
    return 'Riceverai circa: $amount';
  }

  @override
  String get limitOrdersWalletTitle => 'Scegli il portafoglio di destinazione';

  @override
  String get limitOrdersWalletDescription =>
      'Quando l\'ordine verrà eseguito, i bitcoin saranno inviati a questo portafoglio predefinito.';

  @override
  String get limitOrdersManageDefaultWallets =>
      'Gestisci i portafogli predefiniti';

  @override
  String get limitOrdersWalletBitcoin => 'Indirizzo Bitcoin';

  @override
  String get limitOrdersWalletLightning => 'Indirizzo Lightning';

  @override
  String get limitOrdersWalletLiquid => 'Indirizzo Liquid';

  @override
  String get limitOrdersConfirmationTitle =>
      'Rivedi e conferma l\'ordine limite:';

  @override
  String limitOrdersBalancePayment(String currency) {
    return 'Saldo $currency';
  }

  @override
  String get limitOrdersTermsNotice =>
      'Confermando accetti i termini di Bull Bitcoin. Il prezzo finale di acquisto include lo spread previsto per il tuo account.';

  @override
  String get limitOrdersConfirm => 'Conferma';

  @override
  String get limitOrdersCreatedTitle => 'Ordine limite attivo';

  @override
  String limitOrdersCreatedMessage(String amount, String price) {
    return 'Il tuo ordine acquisterà $amount quando il prezzo indice raggiungerà $price.';
  }

  @override
  String get limitOrdersBackToExchange => 'Torna a Exchange';

  @override
  String get limitOrderInvalidTargetError =>
      'Scegli un prezzo obiettivo inferiore al prezzo indice attuale.';

  @override
  String get limitOrderInvalidAmountError =>
      'Inserisci un importo maggiore di zero e non superiore al saldo disponibile.';

  @override
  String get limitOrdersYourWalletsTitle => 'I tuoi portafogli';

  @override
  String get limitOrdersLightningAddressLabel => 'Indirizzo Lightning';

  @override
  String get limitOrdersLightningAddressError =>
      'Inserisci un indirizzo Lightning valido, non una fattura Lightning';

  @override
  String limitOrdersAmountBelowOnchainMin(String amount) {
    return 'L\'importo è inferiore al minimo on-chain di $amount';
  }

  @override
  String limitOrdersAmountBelowLiquidMin(String amount) {
    return 'L\'importo è inferiore al minimo Liquid di $amount';
  }

  @override
  String limitOrdersAmountAboveLightningMax(String amount) {
    return 'L\'importo supera il massimo Lightning di $amount';
  }

  @override
  String get limitOrdersViewOrder => 'Visualizza i dettagli dell\'ordine';

  @override
  String get limitOrdersInsufficientBalance => 'Saldo insufficiente';

  @override
  String get limitOrdersInsufficientBalanceMessage =>
      'Non hai abbastanza fondi per creare questo ordine.';

  @override
  String get limitOrdersFundAccount => 'Deposita fondi';

  @override
  String get exchangeBrandName => 'BULL BITCOIN';

  @override
  String get exchangeLandingConnectAccount =>
      'Collega il tuo account dell\'exchange Bull Bitcoin';

  @override
  String get exchangeLandingRecommendedExchange =>
      'Exchange Bitcoin consigliato';

  @override
  String get exchangeFeatureSelfCustody =>
      '• Acquista Bitcoin direttamente in autocustodia';

  @override
  String get exchangeFeatureDcaOrders =>
      '• PAC, ordini limite e acquisto automatico';

  @override
  String get exchangeFeatureSellBitcoin =>
      '• Vendi Bitcoin e fatti pagare in Bitcoin';

  @override
  String get exchangeFeatureBankTransfers =>
      '• Invia bonifici e paga bollette con i tuoi bitcoin';

  @override
  String get exchangeFeatureCustomerSupport =>
      '• Chatta con l\'assistenza clienti';

  @override
  String get exchangeFeatureUnifiedHistory =>
      '• Cronologia unificata delle transazioni';

  @override
  String get exchangeLandingDisclaimerLegal =>
      'L\'accesso ai servizi di exchange sarà limitato ai paesi in cui Bull Bitcoin può operare legalmente e può richiedere la verifica KYC.';

  @override
  String get exchangeLandingDisclaimerNotAvailable =>
      'I servizi di exchange di criptovalute non sono disponibili nell\'app mobile Bull Bitcoin.';

  @override
  String get exchangeLoginButton => 'Accedi o registrati';

  @override
  String get exchangeGoToWebsiteButton =>
      'Vai al sito dell\'exchange Bull Bitcoin';

  @override
  String get exchangeErrorSigningOut =>
      'Non è stato possibile completare la disconnessione. Riprova.';

  @override
  String get exchangeErrorLoadingAnnouncements =>
      'Non è stato possibile caricare gli annunci.';

  @override
  String get exchangeErrorRequestingAccountDeletion =>
      'Non è stato possibile inviare la tua richiesta di eliminazione dell\'account. Riprova.';
}
