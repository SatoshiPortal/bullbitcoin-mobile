// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'exchange_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class ExchangeLocalizationsDe extends ExchangeLocalizations {
  ExchangeLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get exchangeAccountInfoEmailLabel => 'E-Mail';

  @override
  String get exchangeAccountInfoFirstNameLabel => 'Vorname';

  @override
  String get exchangeAccountInfoLastNameLabel => 'Nachname';

  @override
  String get exchangeAccountInfoLoadErrorMessage =>
      'Kontoinformationen können nicht geladen werden.';

  @override
  String get exchangeAccountInfoTitle => 'Kontoinformationen';

  @override
  String get exchangeAccountInfoUserNumberCopiedMessage =>
      'Benutzernummer in Zwischenablage kopiert';

  @override
  String get exchangeAccountInfoUserNumberLabel => 'Benutzernummer';

  @override
  String get exchangeAccountInfoVerificationIdentityVerified =>
      'Identität bestätigt';

  @override
  String get exchangeAccountInfoVerificationLevelLabel => 'Verifizierungsstufe';

  @override
  String get exchangeAccountInfoVerificationLightVerification =>
      'Basisverifizierung';

  @override
  String get exchangeAccountInfoVerificationLimitedVerification =>
      'Begrenzte Überprüfung';

  @override
  String get exchangeAccountInfoVerificationNotVerified => 'Nicht verifiziert';

  @override
  String get exchangeAppSettingsDefaultCurrencyLabel => 'Standardwährung';

  @override
  String get exchangeAppSettingsEmailNotificationsDescription =>
      'Erhalten Sie E-Mail-Benachrichtigungen zu Bestellungen und Kontoaktualisierungen.';

  @override
  String get exchangeAppSettingsEmailNotificationsLabel =>
      'E-Mail-Benachrichtigungen';

  @override
  String get exchangeAppSettingsPreferredLanguageLabel => 'Bevorzugte Sprache';

  @override
  String get exchangeAppSettingsSaveButton => 'Speichern';

  @override
  String get exchangeAppSettingsSaveSuccessMessage =>
      'Einstellungen erfolgreich gespeichert.';

  @override
  String get exchangeAppSettingsValidationWarning =>
      'Bitte legen Sie vor dem Speichern sowohl die Sprach- als auch die Währungseinstellungen fest.';

  @override
  String get exchangeAuthErrorMessage =>
      'Ein Fehler ist aufgetreten. Bitte versuchen Sie, sich erneut anzumelden.';

  @override
  String get exchangeBitcoinWalletsTitle => 'Standard-Bitcoin-Wallets';

  @override
  String get exchangeErrorNetwork =>
      'Überprüfen Sie Ihre Internetverbindung und versuchen Sie es erneut.';

  @override
  String get exchangeErrorSavingPreferences =>
      'Ihre Einstellungen konnten nicht gespeichert werden. Bitte versuchen Sie es erneut.';

  @override
  String get exchangeFileUploadButton => 'Hochladen';

  @override
  String get exchangeFileUploadDocumentTitle => 'Beliebiges Dokument hochladen';

  @override
  String get exchangeFileUploadInstructions =>
      'Wenn Sie weitere Dokumente hochladen möchten, tun Sie dies bitte hier.';

  @override
  String get exchangeFileUploadStatusAccepted => 'Angenommen';

  @override
  String get exchangeFileUploadStatusInReview => 'In Bearbeitung';

  @override
  String get exchangeFileUploadStatusRejectedBadge => 'Abgelehnt';

  @override
  String get exchangeFileUploadSuccess => 'Datei erfolgreich hochgeladen';

  @override
  String get exchangeFileUploadTapToReupload =>
      'Tippen Sie, um erneut hochzuladen.';

  @override
  String get exchangeFileUploadTitle => 'Sicherer Datei-Upload';

  @override
  String get exchangeReferralsApplyToJoinMessage =>
      'Bewerben Sie sich, um dem Programm beizutreten.';

  @override
  String get exchangeReferralsContactSupportMessage =>
      'Kontaktieren Sie den Support, um mehr über unser Referral-Programm zu erfahren.';

  @override
  String get exchangeReferralsJoinMissionTitle => 'Treten Sie der Mission bei';

  @override
  String get exchangeReferralsMissionLink => 'bullbitcoin.com/mission';

  @override
  String get exchangeReferralsTitle => 'Referral-Codes';

  @override
  String get exchangeSecurityAccessSettingsButton => 'Zugriffseinstellungen';

  @override
  String get exchangeSecurityManage2FAPasswordLabel =>
      '2FA und Passwort verwalten';

  @override
  String get exchangeSettingsAccountInformationTitle => 'Kontoinformationen';

  @override
  String get exchangeSettingsErrorDocumentAlreadySubmitted =>
      'Es wurde bereits ein Dokument eingereicht.';

  @override
  String get exchangeSettingsErrorDocumentEmpty =>
      'Diese Datei ist leer. Wählen Sie eine andere.';

  @override
  String get exchangeSettingsErrorDocumentTooLarge =>
      'Diese Datei ist zu groß. Wählen Sie eine kleinere.';

  @override
  String get exchangeSettingsErrorDocumentTypeNotAllowed =>
      'Dieser Dateityp wird nicht akzeptiert. Wählen Sie eine andere Datei.';

  @override
  String get exchangeSettingsErrorDocumentUnreadable =>
      'Diese Datei konnte nicht gelesen werden. Wählen Sie eine andere.';

  @override
  String get exchangeSettingsErrorLoadingAccount =>
      'Ihre Kontodaten konnten nicht geladen werden. Bitte versuchen Sie es erneut.';

  @override
  String get exchangeSettingsErrorLoadingStatistics =>
      'Ihre Handelsstatistiken konnten nicht geladen werden. Bitte versuchen Sie es erneut.';

  @override
  String get exchangeSettingsErrorLoadingUploadStatus =>
      'Ihr Upload-Status konnte nicht geladen werden. Bitte versuchen Sie es erneut.';

  @override
  String get exchangeSettingsErrorUploadingDocument =>
      'Das Dokument konnte nicht hochgeladen werden. Bitte versuchen Sie es erneut.';

  @override
  String get exchangeSettingsLogInTitle => 'Anmelden';

  @override
  String get exchangeSettingsRecipientsTitle => 'Empfänger';

  @override
  String get exchangeSettingsReferralsTitle => 'Referral-Programm';

  @override
  String get exchangeSettingsSecuritySettingsTitle =>
      'Sicherheitseinstellungen';

  @override
  String get exchangeSettingsTransactionsTitle => 'Transaktionen';

  @override
  String exchangeStatisticsAsOf(String date) {
    return 'Stand: $date.';
  }

  @override
  String get exchangeStatisticsAveragePrice => 'Durchschnittspreis';

  @override
  String get exchangeStatisticsBillerStats => 'Verkäuferstatistiken';

  @override
  String get exchangeStatisticsBuyAvgPriceDesc =>
      'Durchschnittspreis pro Bitcoin beim Kauf';

  @override
  String get exchangeStatisticsBuySellRatio => 'Kauf-/Verkaufsverhältnis';

  @override
  String get exchangeStatisticsBuySellRatioDesc =>
      'Prozentsatz des Gesamtvolumens zwischen Kauf und Verkauf';

  @override
  String get exchangeStatisticsBuyStats => 'Kauf-Statistiken';

  @override
  String get exchangeStatisticsBuyTradeCountDesc => 'Anzahl der Bitcoin-Käufe';

  @override
  String get exchangeStatisticsBuyVolumeDesc =>
      'Gesamtbetrag, der für den Kauf von Bitcoin ausgegeben wurde';

  @override
  String exchangeStatisticsCurrency(String currency) {
    return 'Währung: $currency';
  }

  @override
  String get exchangeStatisticsNoData => 'Keine Statistiken verfügbar.';

  @override
  String get exchangeStatisticsOrderStats => 'Bestell-Statistiken';

  @override
  String get exchangeStatisticsSellAvgPriceDesc =>
      'Durchschnittspreis pro Bitcoin beim Verkauf';

  @override
  String get exchangeStatisticsSellStats => 'Verkaufs-Statistiken';

  @override
  String get exchangeStatisticsSellTradeCountDesc =>
      'Anzahl der Bitcoin-Verkäufe';

  @override
  String get exchangeStatisticsSellVolumeDesc =>
      'Gesamtbetrag, der aus dem Verkauf von Bitcoin erhalten wurde';

  @override
  String get exchangeStatisticsTitle => 'Statistiken';

  @override
  String get exchangeStatisticsTotalAmount => 'Gesamtbetrag';

  @override
  String get exchangeStatisticsTotalVolume => 'Gesamtes Handelsvolumen';

  @override
  String get exchangeStatisticsTotalVolumeDesc =>
      'Kombiniertes Kauf- und Verkaufsvolumen in Fiat-Währungen';

  @override
  String get exchangeStatisticsTradeCount => 'Anzahl der Trades';

  @override
  String exchangeStatisticsTradeCountByCurrency(int count, String currency) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Trades ($currency)',
      one: '1 Trade ($currency)',
    );
    return '$_temp0';
  }

  @override
  String exchangeStatisticsTradeCountValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Trades',
      one: '1 Trade',
    );
    return '$_temp0';
  }

  @override
  String get exchangeStatisticsVolume => 'Volumen';

  @override
  String get exchangeSupportChatAttachFileTooltip => 'Attach a file';

  @override
  String get exchangeSupportChatAttachLogsFailed =>
      'Anhängen der Protokolle fehlgeschlagen. Bitte versuchen Sie es erneut.';

  @override
  String get exchangeSupportChatAttachLogsTooltip => 'Attach logs';

  @override
  String get exchangeSupportChatAttachmentImage => 'Bild';

  @override
  String get exchangeSupportChatAttachmentUnknownFile => 'Unbekannte Datei';

  @override
  String get exchangeSupportChatEmptyState =>
      'Noch keine Nachrichten. Starten Sie ein Gespräch!';

  @override
  String get exchangeSupportChatFetchFileDataFailed =>
      'Abrufen der Datei fehlgeschlagen.';

  @override
  String get exchangeSupportChatInputHint => 'Nachricht eingeben…';

  @override
  String get exchangeSupportChatLoadAttachmentError =>
      'Der Anhang konnte nicht geöffnet werden. Bitte versuchen Sie es erneut.';

  @override
  String get exchangeSupportChatLoadMessagesError =>
      'Nachrichten konnten nicht geladen werden. Bitte versuchen Sie es erneut.';

  @override
  String get exchangeSupportChatMessageEmptyError =>
      'Nachricht darf nicht leer sein.';

  @override
  String get exchangeSupportChatMessageRequired =>
      'Eine Nachricht ist erforderlich.';

  @override
  String get exchangeSupportChatPickFilesFailed =>
      'Auswahl der Dateien fehlgeschlagen. Bitte versuchen Sie es erneut.';

  @override
  String get exchangeSupportChatSendMessageError =>
      'Ihre Nachricht konnte nicht gesendet werden. Bitte versuchen Sie es erneut.';

  @override
  String get exchangeSupportChatSendTooltip => 'Send message';

  @override
  String get exchangeSupportChatTitle => 'Support-Chat';

  @override
  String get exchangeSupportChatYesterday => 'Gestern';

  @override
  String get exchangeSupportLoginChatRequired =>
      'Um persönlichen Support zu erhalten, müssen Sie sich zuerst in Ihrem Bull-Bitcoin-Konto anmelden. Es ist 100 % kostenlos und es ist kein KYC erforderlich, nur eine E-Mail-Adresse.';

  @override
  String get loginButton => 'Anmelden';

  @override
  String get notLoggedInTitle => 'Sie sind nicht angemeldet';

  @override
  String get oopsSomethingWentWrong => 'Ups! Etwas ist schief gelaufen';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get settingsAppSettingsTitle => 'App-Einstellungen';

  @override
  String get exchangeSupportChatLogDraft => 'Here are my logs';

  @override
  String get settingsAccountSettingsTitle => 'Kontoeinstellungen';

  @override
  String get settingsErrorSavingSetting =>
      'Diese Einstellung konnte nicht gespeichert werden. Bitte versuchen Sie es erneut.';

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
  String get fundExchangeTitle => 'Einzahlung';

  @override
  String get fundExchangeAccountTitle => 'Konto aufladen';

  @override
  String get fundExchangeAccountSubtitle =>
      'Wählen Sie Ihr Land und Ihre Zahlungsmethode';

  @override
  String get fundExchangeRestrictedTitle => 'Einzahlung nicht verfügbar';

  @override
  String get fundExchangeRestrictedMessage =>
      'Einzahlungen sind für Ihr Konto nicht verfügbar. Bitte kontaktieren Sie den Support für weitere Informationen.';

  @override
  String get fundExchangeWarningTitle => 'Achtung: Betrugsrisiko';

  @override
  String get fundExchangeWarningDescription =>
      'Wenn jemand Sie auffordert, Bitcoin zu kaufen oder Ihnen „zu helfen“, seien Sie vorsichtig, denn möglicherweise versucht er, Sie zu betrügen!';

  @override
  String get fundExchangeWarningTacticsTitle => 'Gängige Betrugstaktiken';

  @override
  String get fundExchangeWarningTactic1 =>
      'Sie versprechen eine Rendite auf die Investition.';

  @override
  String get fundExchangeWarningTactic2 => 'Sie bieten Ihnen einen Kredit an.';

  @override
  String get fundExchangeWarningTactic3 =>
      'Sie sagen, sie arbeiten für Schulden- oder Steuereintreibung.';

  @override
  String get fundExchangeWarningTactic4 =>
      'Sie bitten darum, Bitcoin an ihre Adresse zu senden.';

  @override
  String get fundExchangeWarningTactic5 =>
      'Sie bitten darum, Bitcoin an eine andere Plattform zu senden.';

  @override
  String get fundExchangeWarningTactic6 =>
      'Sie möchten, dass Sie Ihren Bildschirm teilen.';

  @override
  String get fundExchangeWarningTactic7 =>
      'Man sagt Ihnen, dass Sie sich keine Sorgen um diese Warnung machen müssen.';

  @override
  String get fundExchangeWarningTactic8 =>
      'Sie drängen Sie zu schneller Zahlung.';

  @override
  String get fundExchangeWarningConfirmation =>
      'Ich bestätige, dass ich nicht von jemand anderem gebeten wurde, Bitcoin für ihn zu kaufen.';

  @override
  String get fundExchangeContinueButton => 'Fortfahren';

  @override
  String get fundExchangeScamConsentError =>
      'Ihre Zustimmung konnte nicht registriert werden. Bitte versuchen Sie es erneut.';

  @override
  String get fundExchangeDoneButton => 'Fertig';

  @override
  String get fundExchangeJurisdictionCanada => '🇨🇦 Kanada';

  @override
  String get fundExchangeJurisdictionEurope => '🇪🇺 Europa (SEPA)';

  @override
  String get fundExchangeJurisdictionMexico => '🇲🇽 Mexiko';

  @override
  String get fundExchangeJurisdictionCostaRica => '🇨🇷 Costa Rica';

  @override
  String get fundExchangeJurisdictionArgentina => '🇦🇷 Argentinien';

  @override
  String get fundExchangeJurisdictionColombia => '🇨🇴 Kolumbien';

  @override
  String get fundExchangeMethodEmailETransfer => 'E-Mail E-Transfer';

  @override
  String get fundExchangeMethodEmailETransferSubtitle =>
      'Einfachste und schnellste Methode (sofort)';

  @override
  String get fundExchangeMethodBankTransferWire =>
      'Banküberweisung (Wire oder EFT)';

  @override
  String get fundExchangeMethodBankTransferWireSubtitle =>
      'Die beste und zuverlässigste Option für größere Beträge (am selben oder nächsten Tag)';

  @override
  String get fundExchangeMethodOnlineBillPayment => 'Online-Rechnungszahlung';

  @override
  String get fundExchangeMethodOnlineBillPaymentSubtitle =>
      'Die langsamste Option, kann jedoch über Online-Banking durchgeführt werden (3–4 Werktage)';

  @override
  String get fundExchangeMethodCanadaPost =>
      'Bargeld- oder Debit-Zahlung bei Canada Post';

  @override
  String get fundExchangeMethodCanadaPostSubtitle =>
      'Am besten für diejenigen geeignet, die lieber persönlich bezahlen möchten';

  @override
  String get fundExchangeMethodInstantSepa => 'SEPA-Sofort und SEPA-Standard';

  @override
  String get fundExchangeMethodInstantSepaSubtitle =>
      'Schnellste – Nur für Transaktionen unter 30.000 €';

  @override
  String get fundExchangeMethodRegularSepa => 'Reguläres SEPA';

  @override
  String get fundExchangeMethodRegularSepaSubtitle =>
      'Nur für größere Transaktionen über 30.000 €';

  @override
  String get fundExchangeBankTransferWireTitle => 'Banküberweisung (Wire)';

  @override
  String get fundExchangeBankTransferWireDescription =>
      'Senden Sie eine Überweisung von Ihrem Bankkonto mit den Bull Bitcoin-Bankdaten unten. Ihre Bank benötigt möglicherweise nur einige dieser Daten.';

  @override
  String get fundExchangeBankTransferWireTimeframe =>
      'Jeder Betrag, den Sie senden, wird innerhalb von 1–2 Werktagen zu Ihrem Bull Bitcoin-Guthaben hinzugefügt.';

  @override
  String get fundExchangeLabelBeneficiaryName => 'Name des Begünstigten';

  @override
  String get fundExchangeHelpBeneficiaryName =>
      'Verwenden Sie unseren offiziellen Firmennamen. Verwenden Sie nicht „Bull Bitcoin“.';

  @override
  String get fundExchangeLabelTransferCode =>
      'Überweisungscode (bitte als Verwendungszweck angeben)';

  @override
  String get fundExchangeHelpTransferCode =>
      'Fügen Sie dies als Verwendungszweck der Überweisung hinzu.';

  @override
  String get fundExchangeInfoTransferCode =>
      'Sie müssen den Überweisungscode als „Nachricht“ oder „Verwendungszweck“ bei der Zahlung angeben.';

  @override
  String get fundExchangeLabelBankAccountDetails => 'Bankverbindung';

  @override
  String get fundExchangeLabelSwiftCode => 'SWIFT-Code';

  @override
  String get fundExchangeLabelInstitutionNumber => 'Institutionsnummer';

  @override
  String get fundExchangeLabelTransitNumber => 'Transitnummer';

  @override
  String get fundExchangeLabelRoutingNumber => 'Bankleitzahl';

  @override
  String get fundExchangeLabelBeneficiaryAddress => 'Begünstigtenadresse';

  @override
  String get fundExchangeLabelBankName => 'Name der Bank';

  @override
  String get fundExchangeLabelBankAddress => 'Adresse unserer Bank';

  @override
  String get fundExchangeETransferTitle => 'E-Transfer-Details';

  @override
  String get fundExchangeETransferDescription =>
      'Jeder Betrag, den Sie von Ihrer Bank über E-Mail E-Transfer mit den untenstehenden Informationen senden, wird innerhalb von wenigen Minuten auf Ihr Bull Bitcoin-Guthaben gutgeschrieben.';

  @override
  String get fundExchangeETransferLabelBeneficiaryName =>
      'Als E-Transfer-Empfänger verwenden';

  @override
  String get fundExchangeETransferLabelEmail =>
      'Senden Sie den E-Transfer an diese E-Mail-Adresse.';

  @override
  String get fundExchangeETransferLabelSecretQuestion => 'Geheime Frage';

  @override
  String get fundExchangeETransferLabelSecretAnswer => 'Geheime Antwort';

  @override
  String get fundExchangeOnlineBillPaymentTitle => 'Online-Rechnungszahlung';

  @override
  String get fundExchangeOnlineBillPaymentDescription =>
      'Jeder Betrag, den Sie über die Online-Abrechnungsfunktion Ihrer Bank mit den untenstehenden Informationen senden, wird innerhalb von 3–4 Werktagen auf Ihr Bull Bitcoin-Guthaben gutgeschrieben.';

  @override
  String get fundExchangeOnlineBillPaymentLabelBillerName =>
      'Suchen Sie die Liste der Biller Ihrer Bank für diesen Namen.';

  @override
  String get fundExchangeOnlineBillPaymentHelpBillerName =>
      'Fügen Sie dieses Unternehmen als Zahler hinzu. Es handelt sich um Bull Bitcoins Zahlungsprozessor.';

  @override
  String get fundExchangeCanadaPostTitle =>
      'Bargeld- oder Debit-Zahlung bei Canada Post';

  @override
  String get fundExchangeCanadaPostStep1 =>
      '1. Gehen Sie zu einer beliebigen Canada Post-Filiale.';

  @override
  String get fundExchangeCanadaPostStep2 =>
      '2. Bitten Sie den Kassierer, den „Loadhub“-QR-Code zu scannen.';

  @override
  String get fundExchangeCanadaPostStep3 =>
      '3. Teilen Sie dem Kassierer den Betrag mit, den Sie aufladen möchten.';

  @override
  String get fundExchangeCanadaPostStep4 =>
      '4. Der Kassierer wird Sie bitten, einen amtlichen Ausweis vorzulegen, und überprüfen, ob der Name auf Ihrem Ausweis mit dem Namen in Ihrem Bull Bitcoin-Konto übereinstimmt.';

  @override
  String get fundExchangeCanadaPostStep5 =>
      '5. Bezahlen Sie mit Bargeld oder Debitkarte.';

  @override
  String get fundExchangeCanadaPostStep6 =>
      '6. Der Kassierer gibt Ihnen eine Quittung. Bewahren Sie diese als Zahlungsnachweis auf.';

  @override
  String get fundExchangeCanadaPostStep7 =>
      '7. Das Guthaben wird innerhalb von 30 Minuten Ihrem Bull-Bitcoin-Konto gutgeschrieben.';

  @override
  String get fundExchangeCanadaPostQrCodeLabel => 'LoadHub QR-Code';

  @override
  String get fundExchangeSepaTitle => 'SEPA-Überweisung';

  @override
  String get fundExchangeSepaDescription =>
      'Senden Sie eine SEPA-Überweisung von Ihrem Bankkonto mit den untenstehenden Daten.';

  @override
  String get fundExchangeSepaDescriptionExactly => 'genau.';

  @override
  String get fundExchangeInstantSepaInfo =>
      'Nur für Transaktionen unter 20.000 €. Für größere Transaktionen verwenden Sie bitte die reguläre SEPA-Option.';

  @override
  String get fundExchangeRegularSepaInfo =>
      'Nur für Transaktionen über 20.000 €. Für kleinere Transaktionen verwenden Sie bitte die Instant SEPA-Option.';

  @override
  String get fundExchangeLabelIban => 'IBAN Kontonummer';

  @override
  String get fundExchangeLabelBicCode => 'BIC-Code';

  @override
  String get fundExchangeLabelBankAccountCountry => 'Land des Bankkontos';

  @override
  String get fundExchangeInfoBankCountryUk =>
      'Unser Bankland ist das Vereinigte Königreich.';

  @override
  String get fundExchangeInfoBeneficiaryNameLeonod =>
      'Der Name des Empfängers sollte LEONOD sein. Wenn Sie etwas anderes setzen, wird Ihre Zahlung abgelehnt.';

  @override
  String get fundExchangeInfoPaymentDescription =>
      'Fügen Sie in der Zahlungsbeschreibung Ihren Überweisungscode hinzu.';

  @override
  String get fundExchangeHelpBeneficiaryAddress =>
      'Unsere offizielle Adresse, falls diese von Ihrer Bank verlangt wird';

  @override
  String get fundExchangeLabelRecipientName => 'Empfängername';

  @override
  String get fundExchangeLabelBankCountry => 'Land';

  @override
  String get fundExchangeLabelRecipientAddress => 'Empfängeradresse';

  @override
  String get fundExchangeSpeiTitle => 'SPEI-Überweisung';

  @override
  String get fundExchangeSpeiDescription => 'Überweisung mit CLABE';

  @override
  String get fundExchangeSpeiInfo =>
      'Machen Sie eine Einzahlung mit SPEI-Überweisung (sofort).';

  @override
  String get fundExchangeLabelClabe => 'CLABE';

  @override
  String get fundExchangeLabelMemo => 'Memo';

  @override
  String get fundExchangeSinpeTitle => 'SINPE-Transfer';

  @override
  String get fundExchangeSinpeDescription =>
      'Überweisen Sie Costa-Rica-Colón mit SINPE';

  @override
  String get fundExchangeCrIbanCrcTitle => 'Banküberweisung (CRC)';

  @override
  String get fundExchangeCrIbanUsdTitle => 'Banküberweisung (USD)';

  @override
  String get fundExchangeArsBankTransferTitle => 'Banküberweisung';

  @override
  String get fundExchangeArsBankTransferDescription =>
      'Senden Sie eine Banküberweisung von Ihrem Bankkonto mit den genauen argentinischen Bankdaten unten.';

  @override
  String get fundExchangeLabelRecipientNameArs => 'Empfängername';

  @override
  String get fundExchangeLabelCvu => 'CVU';

  @override
  String get fundExchangeErrorLoadingDetails =>
      'Die Zahlungsdetails konnten derzeit nicht geladen werden. Bitte versuchen Sie es erneut und wählen Sie eine andere Zahlungsmethode oder versuchen Sie es später erneut.';

  @override
  String get fundExchangeErrorTitleOrdPo404 => 'Zahlungsoption nicht verfügbar';

  @override
  String get fundExchangeErrorOrdPo404 => 'Keine Zahlungsoption verfügbar';

  @override
  String get fundExchangeErrorTitleRcpPo404 => 'Zahlungsoption nicht verfügbar';

  @override
  String get fundExchangeErrorRcpPo404 =>
      'Sie haben nicht die erforderlichen Berechtigungen, um auf diese Finanzierungsoption zuzugreifen. Entweder ist Ihr KYC unzureichend oder diese Option ist für Ihr Konto nicht verfügbar.';

  @override
  String get fundExchangeErrorTitleRcpPosinpe404 => 'SINPE nicht verfügbar';

  @override
  String get fundExchangeErrorRcpPosinpe404 =>
      'Um auf diese Finanzierungsoption zuzugreifen, muss Ihre Telefonnummer im SINPE-Netzwerk in Costa Rica registriert sein.';

  @override
  String get fundExchangeErrorTitleOrdKyc400 => 'Fehlende KYC-Anforderungen';

  @override
  String get fundExchangeErrorOrdKyc400 =>
      'Sie erfüllen nicht die KYC-Anforderungen für diese Aktion.';

  @override
  String get fundExchangeErrorTitleOrdCop400 =>
      'Ungültige COP-Finanzierungsdaten';

  @override
  String get fundExchangeErrorOrdCop400 =>
      'Ungültige Anfragedaten für COP-Finanzierung';

  @override
  String get fundExchangeErrorOpeningPaymentLink =>
      'Der Zahlungslink konnte nicht geöffnet werden. Bitte versuchen Sie es erneut.';

  @override
  String get fundExchangeErrorTitleOrdCsrcp400 =>
      'Virtuelle Zahlung nicht aktiviert';

  @override
  String get fundExchangeErrorOrdCsrcp400 =>
      'Bitte aktivieren Sie die virtuelle Zahlungsoption für diesen SEPA-Empfänger.';

  @override
  String get fundExchangeErrorTitleRcp400 => 'Ungültige Anfrage';

  @override
  String get fundExchangeErrorRcp400 => 'Ungültige Anfrage';

  @override
  String get fundExchangeErrorFetchingBankCodes =>
      'Fehler beim Abrufen der Bankcodes. Bitte versuchen Sie es später erneut.';

  @override
  String get fundExchangeSinpeDescriptionBold => 'wird abgelehnt.';

  @override
  String get fundExchangeSinpeAddedToBalance =>
      'Sobald die Zahlung gesendet wird, wird diese Ihrem Guthaben hinzugefügt.';

  @override
  String get fundExchangeSinpeLabelPhone =>
      'Senden Sie an diese Telefonnummer.';

  @override
  String get fundExchangeSinpeLabelRecipientName => 'Empfängername';

  @override
  String get fundExchangeCrIbanCrcDescription =>
      'Senden Sie eine Banküberweisung von Ihrem Bankkonto mit den untenstehenden Daten.';

  @override
  String get fundExchangeCrIbanCrcDescriptionBold => 'genau';

  @override
  String get fundExchangeCrIbanCrcDescriptionEnd =>
      '. Das Guthaben wird Ihrem Konto gutgeschrieben.';

  @override
  String get fundExchangeCrIbanCrcLabelIban =>
      'IBAN Kontonummer (nur Kolonnen)';

  @override
  String get fundExchangeCrIbanCrcLabelPaymentDescription =>
      'Zahlungsbeschreibung';

  @override
  String get fundExchangeCrIbanCrcPaymentDescriptionHelp =>
      'Ihr Überweisungscode.';

  @override
  String get fundExchangeCrIbanCrcTransferCodeWarning =>
      'Sie müssen den Überweisungscode als „Nachricht“, „Anweisung“ oder „Beschreibung“ bei der Zahlung angeben. Wenn Sie vergessen, diesen Code einzufügen, kann Ihre Zahlung abgelehnt werden.';

  @override
  String get fundExchangeCrIbanCrcLabelRecipientName => 'Empfängername';

  @override
  String get fundExchangeCrIbanCrcRecipientNameHelp =>
      'Verwenden Sie unseren offiziellen Firmennamen. Verwenden Sie nicht „Bull Bitcoin“.';

  @override
  String get fundExchangeCrIbanCrcLabelCedulaJuridica =>
      'Juristische Identifikationsnummer (Costa Rica)';

  @override
  String get fundExchangeCrIbanUsdDescription =>
      'Senden Sie eine Banküberweisung von Ihrem Bankkonto mit den untenstehenden Daten.';

  @override
  String get fundExchangeCrIbanUsdDescriptionBold => 'genau';

  @override
  String get fundExchangeCrIbanUsdDescriptionEnd =>
      'Das Guthaben wird Ihrem Konto gutgeschrieben.';

  @override
  String get fundExchangeCrIbanUsdLabelIban =>
      'IBAN-Kontonummer (nur US-Dollar)';

  @override
  String get fundExchangeCrIbanUsdLabelPaymentDescription =>
      'Zahlungsbeschreibung';

  @override
  String get fundExchangeCrIbanUsdPaymentDescriptionHelp => 'Ihr Transfercode.';

  @override
  String get fundExchangeCrIbanUsdTransferCodeWarning =>
      'Sie müssen den Transfercode als „Nachricht“ oder „Anweisung“ oder „Beschreibung“ bei der Zahlung hinzufügen. Wenn Sie vergessen, diesen Code einzubeziehen, kann Ihre Zahlung abgelehnt werden.';

  @override
  String get fundExchangeCrIbanUsdLabelRecipientName => 'Empfängername';

  @override
  String get fundExchangeCrIbanUsdRecipientNameHelp =>
      'Verwenden Sie unseren offiziellen Firmennamen. Verwenden Sie nicht „Bull Bitcoin“.';

  @override
  String get fundExchangeCrIbanUsdLabelCedulaJuridica =>
      'Juristische Identifikationsnummer (Costa Rica)';

  @override
  String get fundExchangeCostaRicaMethodSinpeTitle =>
      'SINPE Mobil (Costa Rica)';

  @override
  String get fundExchangeCostaRicaMethodSinpeSubtitle =>
      'Überweisen Sie Costa-Rica-Colón mit SINPE';

  @override
  String get fundExchangeCostaRicaMethodIbanCrcTitle => 'IBAN Costa Rica (CRC)';

  @override
  String get fundExchangeCostaRicaMethodIbanCrcSubtitle =>
      'Überweisung in Costa-Rica-Colón (CRC)';

  @override
  String get fundExchangeCostaRicaMethodIbanUsdTitle => 'IBAN Costa Rica (USD)';

  @override
  String get fundExchangeCostaRicaMethodIbanUsdSubtitle =>
      'Überweisung in US-Dollar (USD)';

  @override
  String get doneButton => 'Fertig';

  @override
  String get fundExchangeSpeiTransfer => 'SPEI-Überweisung';

  @override
  String get fundExchangeSpeiSubtitle => 'Überweisung mit CLABE';

  @override
  String get fundExchangeBankTransfer => 'Banküberweisung';

  @override
  String get fundExchangeBankTransferSubtitle =>
      'Senden Sie eine Banküberweisung von Ihrem Bankkonto';

  @override
  String get fundExchangeCopDailyLimitWarning =>
      'Wenn Sie Ihr tägliches Transaktionslimit überschreiten, schlägt die Transaktion fehl. Sie müssen dann den Kundensupport kontaktieren.';

  @override
  String get fundExchangeCopSenderName => 'Name des Absenders';

  @override
  String get fundExchangeCopIssuingBank => 'Ausstellende Bank';

  @override
  String get fundExchangeCopSelectBankError =>
      'Bitte wählen Sie eine ausstellende Bank aus.';

  @override
  String get fundExchangeCopAmount => 'Betrag';

  @override
  String get fundExchangeCopEnterAmountError =>
      'Bitte geben Sie einen Betrag ein.';

  @override
  String get fundExchangeCopValidAmountError =>
      'Bitte geben Sie einen gültigen Betrag ein.';

  @override
  String get fundExchangeCopGeneratePaymentLink => 'Zahlungslink erstellen';

  @override
  String get fundExchangeCopRedirectMessage =>
      'Sie werden auf eine externe Seite weitergeleitet, um die Zahlung vorzunehmen.';

  @override
  String get fundExchangeCopOpenPaymentLink => 'Zahlungslink öffnen';

  @override
  String get fundExchangeErrorNetwork =>
      'Überprüfen Sie Ihre Internetverbindung und versuchen Sie es erneut.';

  @override
  String get fundExchangeMethodConfidentialSepa => 'Vertrauliches SEPA';

  @override
  String get fundExchangeMethodConfidentialSepaSubtitle =>
      'Eine persönliche virtuelle IBAN, um Geld privat einzuzahlen';

  @override
  String get networkFeatureUnavailable =>
      'This feature is unavailable on the selected network.';

  @override
  String get fundExchangeOnlineBillPaymentLabelAccountNumber =>
      'Dies als Kontonummer hinzufügen';

  @override
  String get fundExchangeOnlineBillPaymentHelpAccountNumber =>
      'Diese einzigartige Kontonummer wird nur für Sie erstellt.';

  @override
  String get fundExchangeSinpeWarningNoBitcoin => 'Tragen Sie nicht';

  @override
  String get fundExchangeSinpeWarningNoBitcoinDescription =>
      'das Wort „Bitcoin“ oder „Crypto“ in der Zahlungsbeschreibung. Dies wird Ihre Zahlung blockieren.';

  @override
  String get exchangeCurrencyDropdownTitle => 'Währung wählen';

  @override
  String get exchangeCurrencyDropdownValidation =>
      'Bitte wählen Sie eine Währung.';

  @override
  String get exchangeAmountInputTitle => 'Betrag eingeben';

  @override
  String get exchangeAmountInputValidationEmpty =>
      'Bitte geben Sie einen Betrag ein.';

  @override
  String get exchangeAmountInputValidationInvalid => 'Ungültiger Betrag';

  @override
  String get exchangeAmountInputValidationZero =>
      'Betrag muss größer als Null sein';

  @override
  String get exchangeAmountInputValidationInsufficient =>
      'Unzureichendes Guthaben';

  @override
  String get exchangeBitcoinWalletsBitcoinAddressLabel => 'Bitcoin-Adresse';

  @override
  String get exchangeBitcoinWalletsLightningAddressLabel =>
      'Lightning (LN-Adresse)';

  @override
  String get exchangeBitcoinWalletsLiquidAddressLabel => 'Liquid-Adresse';

  @override
  String get exchangeBitcoinWalletsEnterAddressHint => 'Adresse eingeben';

  @override
  String get exchangeBitcoinWalletsSaveSuccess =>
      'Wallet-Adresse erfolgreich gespeichert';

  @override
  String get exchangeBitcoinWalletsDescription =>
      'Legen Sie Standard-Wallet-Adressen für automatische Bitcoin-Überweisungen fest.';

  @override
  String get exchangeDcaAddressLabelBitcoin => 'Bitcoin-Adresse';

  @override
  String get exchangeDcaAddressLabelLightning => 'Lightning-Adresse';

  @override
  String get exchangeDcaAddressLabelLiquid => 'Liquid-Adresse';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get delete => 'Löschen';

  @override
  String get save => 'Speichern';

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
  String get settingsTermsOfServiceTitle => 'Geschäftsbedingungen';

  @override
  String get continueButton => 'Fortfahren';

  @override
  String get autoBuyTitle => 'Automatischer Kauf';

  @override
  String get autoBuyDescription =>
      'Kaufen Sie bei jeder Einzahlung auf Ihr Konto automatisch Bitcoin.';

  @override
  String get autoBuyActivate => 'Automatischen Kauf aktivieren';

  @override
  String get autoBuyDeactivate => 'Automatischen Kauf deaktivieren';

  @override
  String get autoBuyCancelTitle => 'Automatischen Kauf deaktivieren?';

  @override
  String get autoBuyCancelMessage =>
      'Bei Ihrer nächsten Kontoeinzahlung wird nicht mehr automatisch Bitcoin gekauft.';

  @override
  String get autoBuyDeactivateConfirm => 'Ja, deaktivieren';

  @override
  String get autoBuyHowItWorks => 'So funktioniert es';

  @override
  String get autoBuyConnectWallet =>
      'Verbinden Sie Ihre Bitcoin-, Lightning- oder Liquid-Wallet.';

  @override
  String get autoBuyPurchaseCreated =>
      'Bei jeder Einzahlung auf Ihr Bull Bitcoin-Konto wird automatisch ein Bitcoin-Kauf ausgelöst.';

  @override
  String get autoBuyBitcoinSent =>
      'Bitcoin wird direkt an Ihre eigene Wallet gesendet.';

  @override
  String get autoBuyRiskDisclaimer =>
      'Die Ausführung des Kaufauftrags kann nicht garantiert werden. Verzögerungen oder Kursänderungen zwischen Einzahlung und Kauf können den tatsächlich angewandten Kurs verändern.';

  @override
  String get autoBuyGetStarted => 'Automatischen Kauf einrichten';

  @override
  String get autoBuyConfirmTitle => 'Automatischen Kauf bestätigen';

  @override
  String get autoBuyInfoMessage =>
      'Jeder Betrag, den Sie Ihrem Konto hinzufügen, wird zum aktuellen Wechselkurs in Bitcoin umgewandelt und an Ihre Wallet gesendet.';

  @override
  String get autoBuyAccountUnavailableError =>
      'Ihr Bull Bitcoin-Konto ist nicht verfügbar. Versuchen Sie es später erneut.';

  @override
  String get autoBuyWalletRequiredError =>
      'Fügen Sie mindestens eine Standardadresse für Bitcoin, Lightning oder Liquid hinzu.';

  @override
  String get autoBuyUpdateError =>
      'Der automatische Kauf konnte nicht aktualisiert werden. Versuchen Sie es später erneut.';

  @override
  String get exchangeAuthLoginFailedTitle => 'Anmeldung fehlgeschlagen';

  @override
  String get exchangeAuthLoginFailedMessage =>
      'Ein Fehler ist aufgetreten. Bitte versuchen Sie es erneut, sich anzumelden.';

  @override
  String get exchangeAuthLoginFailedOkButton => 'OK';

  @override
  String get exchangeTradingUnavailable => 'Trading is unavailable.';

  @override
  String get settingsScreenTitle => 'Einstellungen';

  @override
  String get transactionHistoryTitle => 'Transaktionsverlauf';

  @override
  String get exchangeHomeDepositButton => 'Einzahlen';

  @override
  String get exchangeHomeWithdrawButton => 'Abheben';

  @override
  String get exchangeDcaUnableToGetConfig =>
      'Sparplan-Einstellungen konnten nicht abgerufen werden';

  @override
  String get exchangeDcaDeactivateTitle => 'Sparplan deaktivieren';

  @override
  String get exchangeDcaActivateTitle => 'Sparplan aktivieren';

  @override
  String get exchangeDcaHideSettings => 'Einstellungen ausblenden';

  @override
  String get exchangeDcaViewSettings => 'Einstellungen anzeigen';

  @override
  String get exchangeDcaCancelDialogTitle => 'Bitcoin-Sparplan beenden?';

  @override
  String get exchangeDcaCancelDialogMessage =>
      'Ihr regelmäßiger Bitcoin-Kaufplan wird beendet und geplante Käufe werden eingestellt. Um ihn wieder aufzunehmen, müssen Sie einen neuen Plan erstellen.';

  @override
  String get exchangeDcaCancelDialogCancelButton => 'Abbrechen';

  @override
  String get exchangeDcaCancelDialogConfirmButton => 'Ja, beenden';

  @override
  String get exchangeDcaFrequencyHour => 'Stunde';

  @override
  String get exchangeDcaFrequencyDay => 'Tag';

  @override
  String get exchangeDcaFrequencyWeek => 'Woche';

  @override
  String get exchangeDcaFrequencyMonth => 'Monat';

  @override
  String get exchangeDcaNetworkBitcoin => 'Bitcoin-Netzwerk';

  @override
  String get exchangeDcaNetworkLightning => 'Lightning-Netzwerk';

  @override
  String get exchangeDcaNetworkLiquid => 'Liquid-Netzwerk';

  @override
  String exchangeDcaSummaryMessage(
    String amount,
    String frequency,
    String network,
  ) {
    return 'Sie kaufen $amount jeden $frequency über $network, solange Sie Guthaben auf Ihrem Konto haben.';
  }

  @override
  String exchangeDcaAddressDisplay(String addressLabel, String address) {
    return '$addressLabel: $address';
  }

  @override
  String get exchangeKycLevelLight => 'Basis';

  @override
  String get exchangeKycLevelLimited => 'Begrenzt';

  @override
  String get exchangeKycCardTitle => 'Füllen Sie Ihre KYC-Daten aus';

  @override
  String get exchangeKycCardSubtitle => 'Um Transaktionslimits zu entfernen';

  @override
  String get homeActionBuy => 'Kaufen';

  @override
  String get homeActionSell => 'Verkauf';

  @override
  String get homeActionPay => 'Zahlen';

  @override
  String get homeActionTransfer => 'Swap';

  @override
  String get priceChartShowTooltip => 'Show price chart';

  @override
  String get recipientsSearchHint => 'Empfänger anhand Name oder Label suchen…';

  @override
  String get recipientsScreenTitle => 'Empfänger auswählen';

  @override
  String get recipientsScreenSubtitle => 'An wen zahlen Sie?';

  @override
  String get recipientsTabNew => 'Neuer Empfänger';

  @override
  String get recipientsTabList => 'Meine Fiat-Empfänger';

  @override
  String get recipientsPayoutMethod => 'Auszahlungsmethode';

  @override
  String get recipientsFilterByJurisdiction => 'Nach Land filtern:';

  @override
  String get recipientsListEmpty => 'Keine Empfänger gefunden.';

  @override
  String get recipientsContinue => 'Fortfahren';

  @override
  String get recipientsJurisdictionAll => 'Alle Länder';

  @override
  String get recipientsJurisdictionCanada => '🇨🇦 Kanada';

  @override
  String get recipientsJurisdictionEurope => '🇪🇺 Europa (SEPA)';

  @override
  String get recipientsJurisdictionMexico => '🇲🇽 Mexiko';

  @override
  String get recipientsJurisdictionCostaRica => '🇨🇷 Costa Rica';

  @override
  String get recipientsJurisdictionArgentina => '🇦🇷 Argentinien';

  @override
  String get recipientsJurisdictionColombia => '🇨🇴 Kolumbien';

  @override
  String get recipientsTypeInteracEmail => 'E-Mail-Geldtransfer';

  @override
  String get recipientsTypeBillPayment => 'Rechnungszahlung';

  @override
  String get recipientsTypeBankTransfer => 'Banküberweisung';

  @override
  String get recipientsTypeSepa => 'SEPA-Überweisung';

  @override
  String get recipientsTypeSpeiClabe => 'SPEI CLABE';

  @override
  String get recipientsTypeSpeiSms => 'SPEI SMS';

  @override
  String get recipientsTypeSpeiCard => 'SPEI Karte';

  @override
  String get recipientsTypeSinpeIbanUsd => 'SINPE IBAN (USD)';

  @override
  String get recipientsTypeSinpeIbanCrc => 'SINPE IBAN (CRC)';

  @override
  String get recipientsTypeSinpeMovil => 'SINPE Mobil (Costa Rica)';

  @override
  String get recipientsTypeBankAccountAr => 'CBU/CVU Argentinien';

  @override
  String get recipientsTypeBankAccountCo => 'Bankkonto COP';

  @override
  String get recipientsTypeNequi => 'Nequi';

  @override
  String get recipientsInfoEmail => 'E-Mail';

  @override
  String get recipientsInfoPayee => 'Zahlungsempfänger';

  @override
  String get recipientsInfoAccount => 'Konto';

  @override
  String get recipientsInfoPhone => 'Telefon';

  @override
  String get recipientsInfoCard => 'Karte';

  @override
  String get recipientsInfoLabel => 'Bezeichnung';

  @override
  String get recipientsValidationFieldRequired =>
      'Dieses Feld darf nicht leer sein';

  @override
  String get recipientsLabelOptional => 'Bezeichnung (optional)';

  @override
  String get recipientsLabelHint =>
      'Geben Sie eine Bezeichnung für diesen Empfänger ein';

  @override
  String get recipientsFieldName => 'Name';

  @override
  String get recipientsFieldNameHint => 'Name des Empfängers eingeben';

  @override
  String get recipientsFieldRecipientNameLabel => 'Name des Empfängers';

  @override
  String get recipientsFieldPhoneNumber => 'Telefonnummer';

  @override
  String get recipientsFieldPhoneNumberHint => 'Telefonnummer eingeben';

  @override
  String get recipientsFieldSinpePhoneNumberHint =>
      '8 Ziffern ohne Landesvorwahl';

  @override
  String get recipientsFieldDocumentType => 'Ausweistyp des Empfängers';

  @override
  String get recipientsFieldDocumentNumberHint =>
      'Ausweisnummer des Empfängers eingeben';

  @override
  String get recipientsFieldOwnerName => 'Name des Eigentümers';

  @override
  String get recipientsFieldOwnerNameHint => 'Name des Eigentümers eingeben';

  @override
  String get recipientsAccountOwnerQuestion => 'Wem gehört dieses Konto?';

  @override
  String get recipientsAccountOwnerMine => 'Dies ist mein Konto';

  @override
  String get recipientsAccountOwnerSomeoneElse =>
      'Dies ist das Konto einer anderen Person';

  @override
  String get recipientsFieldIban => 'IBAN';

  @override
  String get recipientsFieldIbanHint => 'IBAN eingeben';

  @override
  String get recipientsFieldClabe => 'CLABE';

  @override
  String get recipientsFieldClabeHint => 'CLABE-Nummer eingeben';

  @override
  String get recipientsFieldCvuCbu => 'CBU/CVU';

  @override
  String get recipientsFieldCvuCbuHint => 'Geben Sie die CVU/CBU-Nummer ein';

  @override
  String get recipientsFieldBankInstitution => 'Bankinstitut';

  @override
  String get recipientsFieldBankInstitutionPlaceholder =>
      'Bankinstitut auswählen';

  @override
  String get recipientsValidationBankInstitution =>
      'Bitte wählen Sie ein Bankinstitut aus.';

  @override
  String get recipientsFieldAccountType => 'Kontotyp';

  @override
  String get recipientsAccountTypeSavings => 'Sparkonto';

  @override
  String get recipientsAccountTypeChecking => 'Girokonto';

  @override
  String get recipientsFieldBankAccountNumber => 'Bankkontonummer';

  @override
  String get recipientsFieldBankAccountNumberHint =>
      'Geben Sie die Bankkontonummer ein';

  @override
  String get recipientsCopDocCc => 'Bürgerausweis (Kolumbien)';

  @override
  String get recipientsCopDocCe => 'Ausländerausweis (Kolumbien)';

  @override
  String get recipientsCopDocNit => 'Steueridentifikationsnummer (Kolumbien)';

  @override
  String get recipientsCopDocPassport => 'Reisepass';

  @override
  String get recipientsCopDocTi => 'Identitätskarte (Kolumbien)';

  @override
  String get recipientsCopDocRegistroCivil =>
      'Personenstandsregister (Kolumbien)';

  @override
  String get recipientsCopDocCcRecipientNumber =>
      'Bürgerausweisnummer des Empfängers (Kolumbien)';

  @override
  String get recipientsCopDocCeRecipientNumber =>
      'Ausländerausweisnummer des Empfängers (Kolumbien)';

  @override
  String get recipientsCopDocNitRecipientNumber =>
      'Steuer-ID-Nummer des Empfängers';

  @override
  String get recipientsCopDocPassportRecipientNumber =>
      'Reisepassnummer des Empfängers';

  @override
  String get recipientsCopDocTiRecipientNumber =>
      'Personalausweisnummer des Empfängers';

  @override
  String get recipientsCopDocRegistroCivilRecipientNumber =>
      'Standesamt-Registernummer des Empfängers';

  @override
  String get recipientsFieldDebitCard => 'Debitkartennummer';

  @override
  String get recipientsFieldDebitCardHint => 'Debitkartennummer eingeben';

  @override
  String get recipientsFieldOwnerNameSinpeHint =>
      'Der Name des Kontoinhabers erscheint hier';

  @override
  String get recipientsValidationSinpePhoneCountryCode =>
      'Entfernen Sie die Landesvorwahl (+506). Geben Sie nur die 8-stellige Nummer ein.';

  @override
  String get recipientsValidationSinpePhoneInvalidChars =>
      'Nur Ziffern verwenden (keine Buchstaben oder Symbole)';

  @override
  String get recipientsValidationSinpePhoneTooShort =>
      'Geben Sie alle 8 Ziffern der Telefonnummer ein.';

  @override
  String get recipientsValidationSinpeOwner =>
      'Bitte überprüfen Sie die Telefonnummer.';

  @override
  String get recipientsFieldEmailAddress => 'E-Mail-Adresse';

  @override
  String get recipientsFieldEmailAddressHint => 'E-Mail-Adresse eingeben';

  @override
  String get recipientsFieldSecurityQuestion => 'Sicherheitsfrage';

  @override
  String get recipientsFieldSecurityQuestionHint =>
      'Sicherheitsfrage eingeben (10–40 Zeichen).';

  @override
  String get recipientsFieldSecurityAnswer => 'Sicherheitsantwort';

  @override
  String get recipientsFieldSecurityAnswerHint => 'Sicherheitsantwort eingeben';

  @override
  String get recipientsValidationSecurityQuestionMin =>
      'Die Sicherheitsfrage muss mindestens 10 Zeichen lang sein';

  @override
  String recipientsCharCounter(int count) {
    return '$count/40 Zeichen';
  }

  @override
  String get recipientsFieldInstitutionCode => 'Institutscode';

  @override
  String get recipientsFieldInstitutionCodeHint => 'Institutscode eingeben';

  @override
  String get recipientsFieldInstitutionNumber => 'Institutsnummer';

  @override
  String get recipientsFieldInstitutionNumberHint => 'Institutsnummer eingeben';

  @override
  String get recipientsFieldTransitNumber => 'Transitnummer';

  @override
  String get recipientsFieldTransitNumberHint => 'Transitnummer eingeben';

  @override
  String get recipientsFieldAccountNumber => 'Kontonummer';

  @override
  String get recipientsFieldAccountNumberHint => 'Kontonummer eingeben';

  @override
  String get recipientsFieldDefaultComment => 'Standardkommentar (optional)';

  @override
  String get recipientsFieldDefaultCommentHint => 'Standardkommentar eingeben';

  @override
  String get recipientsFieldCorporateAccount => 'Firmenkonto';

  @override
  String get recipientsFieldFirstName => 'Vorname';

  @override
  String get recipientsFieldFirstNameHint => 'Vornamen eingeben';

  @override
  String get recipientsFieldLastName => 'Nachname';

  @override
  String get recipientsFieldLastNameHint => 'Nachnamen eingeben';

  @override
  String get recipientsFieldCorporateName => 'Firmenname';

  @override
  String get recipientsFieldCorporateNameHint => 'Firmenname eingeben';

  @override
  String get recipientsFieldBillerName => 'Name des Rechnungsstellers';

  @override
  String get recipientsFieldBillerNameHint =>
      'Rechnungssteller suchen und auswählen';

  @override
  String get recipientsValidationBillerSearchMin =>
      'Geben Sie 3 oder mehr Zeichen für die Suchen Sie ein.';

  @override
  String get recipientsValidationBillerSelect =>
      'Bitte wählen Sie einen Rechnungssteller aus der Liste.';

  @override
  String get recipientsFieldPayeeAccountNumber => 'Kontonummer des Empfängers';

  @override
  String get recipientsErrorLoadFailed =>
      'Ihre Empfänger konnten nicht geladen werden. Bitte versuchen Sie es erneut.';

  @override
  String get recipientsErrorSaveFailed =>
      'Dieser Empfänger konnte nicht gespeichert werden. Bitte überprüfen Sie die Angaben und versuchen Sie es erneut.';

  @override
  String get recipientsErrorSinpeLookupFailed =>
      'Wir konnten diese Telefonnummer nicht überprüfen. Bitte prüfen Sie sie und versuchen Sie es erneut.';

  @override
  String get recipientsErrorBillerSearchFailed =>
      'Die Suche nach Zahlungsempfängern ist fehlgeschlagen. Bitte versuchen Sie es erneut.';

  @override
  String get recipientsErrorNetwork =>
      'Überprüfen Sie Ihre Internetverbindung und versuchen Sie es erneut.';

  @override
  String get recipientsListPullToRetry => 'Zum Wiederholen nach unten ziehen.';

  @override
  String get recipientsErrorSavedButNotSelected =>
      'Dieser Empfänger wurde gespeichert, aber wir konnten nicht fortfahren. Sie finden ihn in Ihrer Liste.';

  @override
  String get recipientsTypeConfidentialSepa => 'Vertrauliches SEPA';

  @override
  String get recipientsErrorVirtualIbanNotAvailable =>
      'Sie haben nicht die erforderlichen Berechtigungen, um auf diese Finanzierungsoption zuzugreifen. Entweder ist Ihr KYC unzureichend oder diese Option ist für Ihr Konto nicht verfügbar.';

  @override
  String get recipientsErrorEuResidencyRequired =>
      'Sie müssen in der Europäischen Union ansässig sein, um vertrauliches SEPA zu aktivieren.';

  @override
  String get recipientsConfidentialSepaActivatingTitle =>
      'Empfänger wird aktiviert';

  @override
  String get recipientsConfidentialSepaActivatingDescription =>
      'Ihr Empfänger wird für Vertrauliches SEPA aktiviert. Das kann einige Minuten dauern.';

  @override
  String get recipientsConfidentialSepaNotActivatedTitle =>
      'Empfänger nicht für Vertrauliches SEPA aktiviert';

  @override
  String get recipientsConfidentialSepaNotActivatedDescription =>
      'Dieser Empfänger ist noch nicht für Vertrauliches SEPA aktiviert. Wir aktivieren ihn gerade. Das kann einige Minuten dauern. Sie können stattdessen Sofort- und Standard-SEPA verwenden.';

  @override
  String get recipientsConfidentialSepaActivatedTitle => 'Empfänger aktiviert';

  @override
  String get recipientsConfidentialSepaActivatedDescription =>
      'Ihr Empfänger ist jetzt für Vertrauliches SEPA aktiviert.';

  @override
  String get recipientsConfidentialSepaUseRegularSepa =>
      'Stattdessen Sofort- und Standard-SEPA verwenden';

  @override
  String get recipientsReturnHome => 'Return Home';

  @override
  String get recipientsVirtualIbanIntroTitle =>
      'Vertrauliches SEPA aktivieren?';

  @override
  String get recipientsVirtualIbanNewBadge => 'Neu';

  @override
  String get recipientsVirtualIbanIntroDescription =>
      'Zahlen Sie privat auf Ihr Konto ein – mit einer persönlichen virtuellen IBAN auf Ihren eigenen Namen. Kostenlos.';

  @override
  String get recipientsVirtualIbanIntroSelfTransfer =>
      'Wenn Sie Geld von Ihrer Bank an Bull Bitcoin senden, erscheint es als Überweisung an sich selbst.';

  @override
  String get recipientsVirtualIbanIntroNoTransferCode =>
      'Kein Überweisungscode erforderlich.';

  @override
  String get recipientsVirtualIbanNameWarningTitle =>
      'Wichtig: Namensübereinstimmung erforderlich';

  @override
  String get recipientsVirtualIbanNameWarningDescription =>
      'Der Name des Bankkontos muss exakt mit dem Namen Ihrer virtuellen Bull Bitcoin IBAN übereinstimmen, sonst wird die Überweisung automatisch zurückgesendet. Die Namen stimmen nicht überein? Kontaktieren Sie den Support.';

  @override
  String get recipientsVirtualIbanAccountOwnerName => 'Name des Kontoinhabers';

  @override
  String get recipientsVirtualIbanNameConfirmation =>
      'Ich bestätige, dass der Name mit meinem Bankkonto bzw. meinen Bankkonten übereinstimmt';

  @override
  String get recipientsVirtualIbanActivate => 'Vertrauliches SEPA aktivieren';

  @override
  String get recipientsVirtualIbanActivatingTitle =>
      'Vertrauliches SEPA wird aktiviert…';

  @override
  String get recipientsVirtualIbanActivatingDescription =>
      'Ihre virtuelle IBAN wird erstellt. Dies kann einige Minuten dauern.';

  @override
  String get recipientsVirtualIbanActivatedTitle =>
      'Vertrauliches SEPA aktiviert';

  @override
  String get recipientsVirtualIbanActivatedDescription =>
      'Sie können jetzt Ihre persönliche virtuelle IBAN nutzen, um privat Geld auszuzahlen.';

  @override
  String get recipientsVirtualIbanCopied => 'In die Zwischenablage kopiert';

  @override
  String get recipientsVirtualIbanDone => 'Fertig';

  @override
  String get recipientsVirtualIbanRecipientName => 'Empfängername';

  @override
  String get recipientsVirtualIbanIbanLabel => 'Virtuelle IBAN-Kontonummer';

  @override
  String get recipientsVirtualIbanCountry => 'Land des Bankkontos';

  @override
  String get recipientsVirtualIbanBic => 'BIC-Code';

  @override
  String get recipientsVirtualIbanActivatedFundingDescription =>
      'Sie können jetzt Ihre persönliche virtuelle IBAN nutzen, um privat Geld einzuzahlen.';

  @override
  String get recipientsVirtualIbanShowDetails =>
      'Details meiner virtuellen IBAN anzeigen';

  @override
  String get recipientsVirtualIbanDetailsDescription =>
      'Zahlen Sie privat auf Ihr Konto ein – mit einer persönlichen virtuellen IBAN auf Ihren eigenen Namen. Die Einzahlung erscheint als Zahlung an Sie selbst, ohne dass ein Überweisungscode erforderlich ist.';

  @override
  String get recipientsVirtualIbanBankAddress => 'Bankadresse';

  @override
  String get recipientsVirtualIbanBankAddressHelp =>
      'Die offizielle Bankadresse, falls Ihre Bank diese benötigt.';

  @override
  String get recipientsConfidentialSepaNameMustMatchHint =>
      'Die Namen Ihres Bankkontos und Ihres virtuellen IBAN-Kontos müssen übereinstimmen, sonst werden Überweisungen automatisch zurückgesendet.';

  @override
  String get recipientsFieldBankAccountIban => 'Bankkontonummer (IBAN)';

  @override
  String get recipientsTypeConfidentialSepaDescription =>
      'Auszahlungen erscheinen als Überweisung an Sie selbst mit Ihrem Kontonamen.';

  @override
  String get withdrawAmountTitle => 'Fiat abheben';

  @override
  String get withdrawAmountContinue => 'Fortfahren';

  @override
  String get withdrawConfirmTitle => 'Auszahlung bestätigen';

  @override
  String get withdrawConfirmRecipientName => 'Empfängername';

  @override
  String get withdrawConfirmAmount => 'Betrag';

  @override
  String get withdrawConfirmEmail => 'E-Mail';

  @override
  String get withdrawConfirmPayee => 'Zahlungsempfänger';

  @override
  String get withdrawConfirmAccount => 'Konto';

  @override
  String get withdrawConfirmIban => 'IBAN';

  @override
  String get withdrawConfirmClabe => 'CLABE';

  @override
  String get withdrawConfirmPhone => 'Telefon';

  @override
  String get withdrawConfirmCard => 'Karte';

  @override
  String get withdrawConfirmButton => 'Auszahlung bestätigen';

  @override
  String get withdrawSuccessTitle => 'Abhebung eingeleitet';

  @override
  String get withdrawSuccessOrderDetails => 'Bestelldetails';

  @override
  String get withdrawConfirmBankAccount => 'Bankkonto';

  @override
  String get withdrawOwnershipQuestion => 'Wem gehört dieses Konto?';

  @override
  String get withdrawOwnershipMyAccount => 'Dies ist mein Konto';

  @override
  String get withdrawOwnershipOtherAccount =>
      'Dies ist das Konto einer anderen Person';

  @override
  String get withdrawUnauthenticatedError =>
      'Sie sind nicht authentifiziert. Bitte melden Sie sich an, um fortzufahren.';

  @override
  String withdrawBelowMinAmountError(String amount, String currency) {
    return 'Mindestbetrag ist $amount $currency';
  }

  @override
  String withdrawAboveMaxAmountError(String amount, String currency) {
    return 'Maximaler Betrag ist $amount $currency';
  }

  @override
  String get withdrawInteracSecurityDetailsTitle =>
      'Sicherheitsdaten für den Transfer';

  @override
  String get withdrawInteracSaveAsDefault =>
      'Diese Angaben als Standard speichern';

  @override
  String get withdrawInteracSecurityQuestionLengthError =>
      'Die Sicherheitsfrage muss 3–40 Zeichen lang sein';

  @override
  String get withdrawInteracSecurityAnswerLengthError =>
      'Die Sicherheitsantwort muss 3–40 Zeichen lang sein';

  @override
  String get withdrawInteracSecurityAnswerFormatError =>
      'Verwenden Sie Buchstaben, Zahlen oder Bindestriche ohne Leerzeichen.';

  @override
  String get withdrawUnexpectedError =>
      'Ihre Auszahlung konnte derzeit nicht abgeschlossen werden. Bitte versuchen Sie es erneut oder wenden Sie sich an den Support.';

  @override
  String get withdrawConfidentialSepaNotActivatedError =>
      'Bitte aktivieren Sie die vertrauliche Zahlungsoption für diesen SEPA-Empfänger.';

  @override
  String get limitOrdersTitle => 'Limitaufträge';

  @override
  String get limitOrdersActiveTitle => 'Aktive Limitaufträge';

  @override
  String get limitOrdersCreateNew => 'Neue erstellen';

  @override
  String get limitOrdersMaximumActiveHint =>
      'Stornieren Sie einen aktiven Auftrag, bevor Sie einen weiteren erstellen.';

  @override
  String limitOrdersBuyAt(String price) {
    return 'Kaufen bei $price';
  }

  @override
  String get limitOrdersCancelAll => 'Alle stornieren';

  @override
  String get limitOrdersCancelAllTitle =>
      'Alle aktiven Limitaufträge stornieren?';

  @override
  String get limitOrdersCancelAllMessage =>
      'Dieser Vorgang kann nicht rückgängig gemacht werden. Nach der Stornierung wird keiner dieser Aufträge ausgeführt.';

  @override
  String get limitOrdersDialogConfirm => 'Bestätigen';

  @override
  String get limitOrdersDone => 'Fertig';

  @override
  String get limitOrdersTargetPrice => 'Zielpreis';

  @override
  String get limitOrdersFiatAmount => 'Betrag';

  @override
  String get limitOrdersEstimatedBuyPrice => 'Voraussichtlicher Kaufpreis';

  @override
  String get limitOrderDetailsTitle => 'Details des Limitauftrags';

  @override
  String get limitOrderDetailsStatus => 'Status';

  @override
  String get limitOrderDetailsNumber => 'Auftragsnummer';

  @override
  String get limitOrderDetailsAddress => 'Auszahlungsadresse';

  @override
  String get limitOrderDetailsCreated => 'Erstellt';

  @override
  String get limitOrderDetailsExpires => 'Läuft ab';

  @override
  String get limitOrderCancel => 'Limitauftrag stornieren';

  @override
  String get limitOrderCancelTitle => 'Diesen Limitauftrag stornieren?';

  @override
  String get limitOrderCancelMessage =>
      'Die Stornierung kann nicht rückgängig gemacht werden. Dieser Auftrag wird anschließend nicht mehr ausgeführt.';

  @override
  String get limitOrderStatusActive => 'Aktiv';

  @override
  String get limitOrderStatusExecuted => 'Ausgeführt';

  @override
  String get limitOrderStatusCancelled => 'Storniert';

  @override
  String get limitOrderStatusExpired => 'Abgelaufen';

  @override
  String get limitOrderStatusFailed => 'Fehlgeschlagen';

  @override
  String get limitOrdersAccountUnavailableError =>
      'Ihr Bull-Bitcoin-Konto oder Ihre Guthaben konnten nicht geladen werden. Bitte versuchen Sie es erneut.';

  @override
  String get limitOrderNotFoundError =>
      'Dieser Limitauftrag wurde nicht gefunden.';

  @override
  String get limitOrdersLoadError =>
      'Die Limitaufträge konnten nicht geladen werden. Bitte versuchen Sie es erneut.';

  @override
  String get limitOrderCancellationError =>
      'Der Limitauftrag konnte nicht storniert werden. Bitte versuchen Sie es erneut.';

  @override
  String get limitOrderDetailsEstimatedBitcoin =>
      'Voraussichtlicher Bitcoin-Betrag';

  @override
  String get limitOrdersMaximumActiveError =>
      'Sie haben bereits fünf aktive Limitaufträge. Stornieren Sie einen davon, bevor Sie einen weiteren erstellen.';

  @override
  String get limitOrderInvalidAddressError =>
      'Die ausgewählte Auszahlungsadresse ist ungültig.';

  @override
  String get limitOrderCreationError =>
      'Der Limitauftrag konnte nicht erstellt werden. Bitte versuchen Sie es erneut.';

  @override
  String get exchangeSettingsLogOutTitle => 'Abmelden';

  @override
  String get logoutConfirmationTitle => 'Abmeldung bestätigen';

  @override
  String get logoutConfirmationDescription =>
      'Möchten Sie sich wirklich von Ihrem Bull-Bitcoin-Konto abmelden? Sie müssen sich erneut anmelden, um auf die Handelsfunktionen zugreifen zu können.';

  @override
  String get logoutConfirmationCancel => 'Abbrechen';

  @override
  String get logoutConfirmationLogout => 'Abmelden';

  @override
  String get exchangeSettingsDeleteAccountTitle => 'Konto löschen';

  @override
  String get deleteAccountConfirmationTitle => 'Konto löschen';

  @override
  String get deleteAccountConfirmationDescription =>
      'Dies sendet eine Anforderung zur Kontolöschung an unser Support-Team. Ihr Konto wird innerhalb von 5 Werktagen gelöscht.';

  @override
  String get deleteAccountConfirmationCancel => 'Abbrechen';

  @override
  String get deleteAccountConfirmationDelete => 'Konto löschen';

  @override
  String get deleteAccountSuccessTitle => 'Konto-Löschung angefordert';

  @override
  String get deleteAccountSuccessDescription =>
      'Ihre Anfrage zur Kontolöschung wurde eingegangen. Sie wird innerhalb von 5 Werktagen bearbeitet.';

  @override
  String get deleteAccountSuccessClose => 'Schließen';

  @override
  String get buyEnterAmount => 'Betrag eingeben';

  @override
  String get buyPaymentMethod => 'Zahlungsmethode';

  @override
  String get buyMax => 'Max';

  @override
  String get buySelectWallet => 'Wallet auswählen';

  @override
  String get buyEnterBitcoinAddress => 'Bitcoin-Adresse eingeben';

  @override
  String get buyBitcoinAddressHint => 'BC1QYL7J673H…6Y6ALV70M0';

  @override
  String get buyConfirmPurchase => 'Kauf bestätigen';

  @override
  String buyYouBought(String amount, String fiatAmount) {
    return 'Sie haben $amount für $fiatAmount gekauft';
  }

  @override
  String get buyPayoutWillBeSentIn => 'Die Auszahlung erfolgt in ';

  @override
  String get buyViewDetails => 'Details anzeigen';

  @override
  String get buyAccelerateTransaction => 'Transaktion beschleunigen';

  @override
  String get buyGetConfirmedFaster => 'Beschleunige die Bestätigung';

  @override
  String get buyConfirmExpressWithdrawal => 'Express-Auszahlung bestätigen';

  @override
  String get buyNetworkFeeExplanation =>
      'Die Bitcoin-Netzwerkgebühr wird von dem Betrag, den Sie erhalten, abgezogen und geht an die Bitcoin-Miner.';

  @override
  String get buyNetworkFees => 'Netzwerkgebühren';

  @override
  String get buyEstimatedFeeValue => 'Geschätzte Gebühren';

  @override
  String get buyNetworkFeeRate => 'Netzwerkgebühren';

  @override
  String get buyConfirmationTime => 'Bestätigungszeit';

  @override
  String get buyConfirmationTimeValue => '~10 Minuten';

  @override
  String get buyWaitForFreeWithdrawal => 'Auf kostenlose Auszahlung warten';

  @override
  String get buyConfirmExpress => 'Express-Zahlung bestätigen';

  @override
  String get buyBitcoinSent => 'Bitcoin gesendet!';

  @override
  String get buyThatWasFast => 'Das ging schnell, oder?';

  @override
  String get globalDefaultBitcoinWalletLabel => 'Sichere Bitcoin-Wallet';

  @override
  String get globalDefaultLiquidWalletLabel => 'Sofortzahlungen';

  @override
  String get dcaSuccessTitle => 'Sparplan ist aktiv!';

  @override
  String dcaSuccessMessageHourly(String amount) {
    return 'Sie kaufen $amount jede Stunde.';
  }

  @override
  String dcaSuccessMessageDaily(String amount) {
    return 'Sie kaufen $amount jeden Tag.';
  }

  @override
  String dcaSuccessMessageWeekly(String amount) {
    return 'Sie kaufen $amount jede Woche.';
  }

  @override
  String dcaSuccessMessageMonthly(String amount) {
    return 'Sie kaufen $amount jeden Monat.';
  }

  @override
  String get dcaBackToHomeButton => 'Zurück zum Startbildschirm';

  @override
  String get dcaChooseWalletTitle => 'Bitcoin-Wallet wählen';

  @override
  String get dcaWalletSelectionDescription =>
      'Bitcoin-Käufe werden automatisch nach diesem Zeitplan platziert.';

  @override
  String get dcaNetworkValidationError => 'Bitte wählen Sie ein Netzwerk aus.';

  @override
  String get dcaEnterLightningAddressLabel => 'Lightning-Adresse eingeben';

  @override
  String get dcaUseDefaultLightningAddress =>
      'Verwenden Sie meine Standard-Lightning-Adresse.';

  @override
  String get dcaWalletSelectionContinueButton => 'Fortfahren';

  @override
  String get dcaSelectFrequencyLabel => 'Häufigkeit auswählen';

  @override
  String get dcaSelectWalletTypeLabel => 'Wählen Sie Bitcoin-Wallet-Typ';

  @override
  String get dcaWalletTypeBitcoin => 'Bitcoin (BTC)';

  @override
  String get dcaWalletTypeLightning => 'Lightning-Netzwerk (LN)';

  @override
  String get dcaWalletTypeLiquid => 'Liquid (L-BTC)';

  @override
  String get dcaWalletBitcoinSubtitle => 'Mindestens 0,001 BTC';

  @override
  String get dcaWalletLightningSubtitle =>
      'Erfordert kompatible Wallet, maximal 0,25 BTC';

  @override
  String get dcaWalletLiquidSubtitle => 'Erfordert kompatible Wallet';

  @override
  String get dcaSetupTitle => 'Sparplan einrichten';

  @override
  String get dcaSetupInsufficientBalance => 'Unzureichendes Guthaben';

  @override
  String get dcaSetupInsufficientBalanceMessage =>
      'Sie haben nicht genug Guthaben, um diese Bestellung zu erstellen.';

  @override
  String get dcaSetupFundAccount => 'Konto aufladen';

  @override
  String get dcaSetupScheduleMessage =>
      'Bitcoin-Käufe werden automatisch nach diesem Zeitplan platziert.';

  @override
  String get dcaSetupFrequencyError => 'Bitte wählen Sie eine Häufigkeit.';

  @override
  String get dcaSetupContinue => 'Fortfahren';

  @override
  String get dcaConfirmTitle => 'Sparplan bestätigen';

  @override
  String get dcaConfirmAutoMessage =>
      'Bestellungen werden automatisch nach diesen Einstellungen platziert. Sie können sie jederzeit deaktivieren.';

  @override
  String get dcaConfirmFrequency => 'Häufigkeit';

  @override
  String get dcaConfirmFrequencyHourly => 'Jede Stunde';

  @override
  String get dcaConfirmFrequencyDaily => 'Jeden Tag';

  @override
  String get dcaConfirmFrequencyWeekly => 'Jede Woche';

  @override
  String get dcaConfirmFrequencyMonthly => 'Jeden Monat';

  @override
  String get dcaConfirmAmount => 'Betrag';

  @override
  String get dcaConfirmPaymentMethod => 'Zahlungsmethode';

  @override
  String dcaConfirmPaymentBalance(String currency) {
    return '$currency-Guthaben';
  }

  @override
  String get dcaConfirmOrderType => 'Auftragstyp';

  @override
  String get dcaConfirmOrderTypeValue => 'Wiederkehrender Kauf';

  @override
  String get dcaConfirmNetwork => 'Netzwerk';

  @override
  String get dcaConfirmNetworkBitcoin => 'Bitcoin';

  @override
  String get dcaConfirmNetworkLightning => 'Lightning';

  @override
  String get dcaConfirmNetworkLiquid => 'Liquid';

  @override
  String get dcaConfirmLightningAddress => 'Lightning-Adresse';

  @override
  String get dcaConfirmContinue => 'Fortfahren';

  @override
  String get buyInputTitle => 'Bitcoin kaufen';

  @override
  String get buyInputMinAmountError => 'Mindestbetrag';

  @override
  String get buyInputMaxAmountError => 'Sie können nicht mehr kaufen als.';

  @override
  String get buyInputKycPending => 'KYC-Identitätsprüfung ausstehend';

  @override
  String get buyInputKycMessage =>
      'Sie müssen zuerst die Identitätsprüfung abschließen.';

  @override
  String get buyInputCompleteKyc => 'KYC abschließen';

  @override
  String get buyInputInsufficientBalance => 'Unzureichendes Guthaben';

  @override
  String get buyInputInsufficientBalanceMessage =>
      'Sie haben nicht genug Guthaben, um diese Bestellung zu erstellen.';

  @override
  String get buyInputFundAccount => 'Konto aufladen';

  @override
  String get buyInputContinue => 'Fortfahren';

  @override
  String get buyConfirmTitle => 'Bitcoin kaufen';

  @override
  String get buyConfirmYouPay => 'Sie zahlen';

  @override
  String get buyConfirmYouReceive => 'Sie erhalten';

  @override
  String get buyConfirmBitcoinPrice => 'Bitcoin-Preis';

  @override
  String get buyConfirmPayoutWallet => 'Auszahlungs-Wallet';

  @override
  String get buyConfirmPayoutMethod => 'Auszahlungsmethode';

  @override
  String get buyPayoutMethodLiquid => 'L-BTC auf Liquid';

  @override
  String get buyPayoutMethodBitcoin => 'BTC auf der Bitcoin-Blockchain';

  @override
  String get buyConfirmExternalWallet => 'Externe Bitcoin-Wallet';

  @override
  String get buyConfirmAwaitingConfirmation => 'Warten auf Bestätigung';

  @override
  String get buyUnauthenticatedError =>
      'Sie sind nicht authentifiziert. Bitte melden Sie sich an, um fortzufahren.';

  @override
  String get buyBelowMinAmountError =>
      'Sie versuchen, unter dem Mindestbetrag zu kaufen.';

  @override
  String get buyAboveMaxAmountError =>
      'Sie versuchen, über dem Höchstbetrag zu kaufen.';

  @override
  String get buyUnexpectedError =>
      'Ihre Kaufanfrage konnte derzeit nicht erstellt werden. Bitte versuchen Sie es erneut oder kontaktieren Sie den Support.';

  @override
  String get dcaAccountUnavailableError =>
      'Ihr Konto konnte nicht geladen werden. Prüfen Sie Ihre Verbindung, stellen Sie sicher, dass Sie angemeldet sind, und versuchen Sie es erneut.';

  @override
  String get dcaLightningAddressRequiredError =>
      'Geben Sie eine Lightning-Adresse ein, um Ihre Käufe zu erhalten.';

  @override
  String get dcaReceiveAddressError =>
      'In Ihrer Wallet konnte keine Empfangsadresse vorbereitet werden. Bitte versuchen Sie es erneut.';

  @override
  String get dcaOrderCreationError =>
      'Der Sparplan konnte nicht erstellt werden. Bitte versuchen Sie es später erneut.';

  @override
  String get payjoinInProgress => 'Payjoin wird durchgeführt…';

  @override
  String get payjoinSucceeded => 'Payjoin erfolgreich abgeschlossen';

  @override
  String get payjoinBuyRegularSend =>
      'Bitcoin per regulärer Transaktion an Ihre Wallet gesendet.';

  @override
  String get payjoinUseToggle => 'Payjoin verwenden';

  @override
  String get limitOrdersLightningAddressHint => 'sie@domain.de';

  @override
  String get exchangeQuoteUnavailableError =>
      'We couldn\'t get a fresh price. Try again, or go back and start a new order.';

  @override
  String get buyQuoteExpiredError =>
      'This price has expired. A new one is being loaded; check it before confirming.';

  @override
  String get sellTitle => 'Bitcoin verkaufen';

  @override
  String get sellSelectWallet => 'Wallet auswählen';

  @override
  String get sellWhichWalletQuestion =>
      'Aus welcher Wallet möchten Sie verkaufen?';

  @override
  String get sellExternalWallet => 'Externe Wallet';

  @override
  String get sellFromAnotherWallet =>
      'Verkauf aus einer anderen Bitcoin-Wallet';

  @override
  String get sellAboveMaxAmountError =>
      'Sie versuchen, einen Betrag zu verkaufen, der über dem Höchstbetrag dieser Wallet liegt.';

  @override
  String get sellBelowMinAmountError =>
      'Sie versuchen, unterhalb des Mindestbetrags dieser Wallet zu verkaufen.';

  @override
  String get sellInsufficientBalanceError =>
      'Das Guthaben in der ausgewählten Wallet reicht nicht aus, um diesen Verkaufsauftrag auszuführen.';

  @override
  String get sellUnauthenticatedError =>
      'Sie sind nicht authentifiziert. Bitte melden Sie sich an, um fortzufahren.';

  @override
  String get sellOrderNotFoundError =>
      'Der Verkaufsauftrag wurde nicht gefunden. Bitte versuchen Sie es erneut.';

  @override
  String get sellOrderAlreadyConfirmedError =>
      'Dieser Verkaufsauftrag wurde bereits bestätigt.';

  @override
  String get sellSelectNetwork => 'Netzwerk auswählen';

  @override
  String get sellHowToPayInvoice => 'Wie möchten Sie diese Rechnung bezahlen?';

  @override
  String get sellBitcoinOnChain => 'Bitcoin On-Chain';

  @override
  String get sellLightningNetwork => 'Lightning-Netzwerk';

  @override
  String get sellLiquidNetwork => 'Liquid-Netzwerk';

  @override
  String get sellConfirmPayment => 'Zahlung bestätigen';

  @override
  String get sellPriceWillRefreshIn => 'Der Preis wird aktualisiert in ';

  @override
  String get sellOrderNumber => 'Bestellnummer';

  @override
  String get sellPayoutRecipient => 'Auszahlungsempfänger';

  @override
  String get sellCadBalance => 'CAD-Guthaben';

  @override
  String get sellCrcBalance => 'CRC-Guthaben';

  @override
  String get sellEurBalance => 'EUR-Guthaben';

  @override
  String get sellUsdBalance => 'USD-Guthaben';

  @override
  String get sellMxnBalance => 'MXN-Guthaben';

  @override
  String get sellArsBalance => 'ARS-Guthaben';

  @override
  String get sellCopBalance => 'COP-Guthaben';

  @override
  String get sellPayinAmount => 'Einzahlungsbetrag';

  @override
  String get sellPayoutAmount => 'Auszahlungsbetrag';

  @override
  String get sellExchangeRate => 'Wechselkurs';

  @override
  String get sellPayFromWallet => 'Aus Wallet bezahlen';

  @override
  String get sellInstantPayments => 'Sofortzahlungen';

  @override
  String get sellSecureBitcoinWallet => 'Sichere Bitcoin-Wallet';

  @override
  String get sellFeePriority => 'Priorität';

  @override
  String get sellFastest => 'Schnellste';

  @override
  String get sellAdvancedSettings => 'Erweiterte Einstellungen';

  @override
  String get sellAdvancedOptions => 'Erweiterte Optionen';

  @override
  String get sellReplaceByFeeActivated => 'Gebührenerhöhung aktiviert';

  @override
  String get sellSelectCoinsManually => 'Coins manuell auswählen';

  @override
  String get sellDone => 'Fertig';

  @override
  String get sellPleasePayInvoice => 'Bitte bezahlen Sie diese Rechnung.';

  @override
  String get sellBitcoinAmount => 'Bitcoin-Betrag';

  @override
  String get sellCopyInvoice => 'Invoice kopieren';

  @override
  String get sellShowQrCode => 'QR-Code anzeigen';

  @override
  String get sellQrCode => 'QR-Code';

  @override
  String get sellNoInvoiceData => 'Invoice-Daten nicht verfügbar';

  @override
  String get sellInProgress => 'Verkauf läuft…';

  @override
  String get sellGoHome => 'Zum Startbildschirm';

  @override
  String get sellOrderCompleted => 'Bestellung abgeschlossen!';

  @override
  String get sellBalanceWillBeCredited =>
      'Ihr Guthaben wird gutgeschrieben, sobald Ihre Transaktion eine Bestätigung in der Blockchain erhalten hat.';

  @override
  String sellYouSold(String amount, String fiatAmount) {
    return 'Sie haben $amount für $fiatAmount verkauft';
  }

  @override
  String get payTitle => 'Zahlen';

  @override
  String get payDescriptionLabel => 'Zahlungsbeschreibung (optional)';

  @override
  String get payDescriptionHint => 'Fügen Sie dieser Zahlung eine Notiz hinzu';

  @override
  String get payPaymentDescription => 'Zahlungsbeschreibung';

  @override
  String get payRecipientType => 'Empfängertyp';

  @override
  String get payRecipientName => 'Empfängername';

  @override
  String get payRecipientDetails => 'Angaben zum Empfänger';

  @override
  String get payNoDetailsAvailable => 'Keine Details verfügbar';

  @override
  String get paySelectWallet => 'Wallet auswählen';

  @override
  String get payExternalWallet => 'Externe Wallet';

  @override
  String payAboveMaxAmountError(String amount) {
    return 'Der Höchstbetrag, den Sie mit dieser Wallet zahlen können, beträgt $amount.';
  }

  @override
  String payBelowMinAmountError(String amount) {
    return 'Der Mindestbetrag, den Sie mit dieser Wallet zahlen können, beträgt $amount.';
  }

  @override
  String get payInsufficientBalanceError =>
      'Das Guthaben in der ausgewählten Wallet reicht nicht aus, um diesen Zahlungsauftrag auszuführen.';

  @override
  String get payUnauthenticatedError =>
      'Sie sind nicht authentifiziert. Bitte melden Sie sich an, um fortzufahren.';

  @override
  String get paySelectNetwork => 'Netzwerk auswählen';

  @override
  String get payHowToPayInvoice => 'Wie möchten Sie diese Rechnung bezahlen?';

  @override
  String get payLightningNetwork => 'Lightning-Netzwerk';

  @override
  String get payLiquidNetwork => 'Liquid-Netzwerk';

  @override
  String get payConfirmPayment => 'Zahlung bestätigen';

  @override
  String get payOrderNumber => 'Bestellnummer';

  @override
  String get payPayinAmount => 'Einzahlungsbetrag';

  @override
  String get payPayoutAmount => 'Auszahlungsbetrag';

  @override
  String get payExchangeRate => 'Wechselkurs';

  @override
  String get payPayFromWallet => 'Aus Wallet bezahlen';

  @override
  String get payInstantPayments => 'Sofortzahlungen';

  @override
  String get paySecureBitcoinWallet => 'Sichere Bitcoin-Wallet';

  @override
  String get payFeePriority => 'Priorität';

  @override
  String get payFastest => 'Schnellste';

  @override
  String get payNetworkFees => 'Netzwerkgebühren';

  @override
  String get payAdvancedSettings => 'Erweiterte Einstellungen';

  @override
  String get payAdvancedOptions => 'Erweiterte Optionen';

  @override
  String get paySelectCoinsManually => 'Coins manuell auswählen';

  @override
  String get payDone => 'Fertig';

  @override
  String get payContinue => 'Fortfahren';

  @override
  String get payPleasePayInvoice => 'Bitte bezahlen Sie diese Rechnung.';

  @override
  String get payBitcoinAmount => 'Bitcoin-Betrag';

  @override
  String get payBitcoinPrice => 'Bitcoin-Preis';

  @override
  String get payCopyInvoice => 'Invoice kopieren';

  @override
  String get payShowQrCode => 'QR-Code anzeigen';

  @override
  String get payQrCode => 'QR-Code';

  @override
  String get payNoInvoiceData => 'Invoice-Daten nicht verfügbar';

  @override
  String get payInvalidState => 'Ungültiger Zustand';

  @override
  String get payViewDetails => 'Details anzeigen';

  @override
  String get paySinpeReceipt => 'SINPE-Beleg';

  @override
  String get payCompleted => 'Zahlung abgeschlossen!';

  @override
  String payCompletedDescriptionDetails(String fiatAmount, String recipient) {
    return 'Die Zahlung über $fiatAmount an $recipient wurde abgeschlossen.';
  }

  @override
  String get paySinpeEnviado => 'SINPE ENVIADO!';

  @override
  String get payOrderDetails => 'Bestelldetails';

  @override
  String get paySinpeMonto => 'Betrag';

  @override
  String get paySinpeNumeroOrden => 'Bestellnummer';

  @override
  String get paySinpeNumeroComprobante => 'Referenznummer';

  @override
  String get paySinpeBeneficiario => 'Begünstigter';

  @override
  String get paySinpeOrigen => 'Herkunft';

  @override
  String get payNotAvailable => 'N/A';

  @override
  String get payBitcoinOnchain => 'Bitcoin On-Chain';

  @override
  String get payPaymentInProgress => 'Zahlung läuft!';

  @override
  String payPaymentInProgressDescriptionDetails(
    String fiatAmount,
    String recipient,
  ) {
    return 'Die Zahlung über $fiatAmount an $recipient wird gesendet, sobald Ihre Transaktion eine On-Chain-Bestätigung erhalten hat.';
  }

  @override
  String payPaymentPayinConfirmedDescriptionDetails(
    String fiatAmount,
    String recipient,
  ) {
    return 'Ihre Transaktion wurde bestätigt. Die Zahlung über $fiatAmount an $recipient wird verarbeitet.';
  }

  @override
  String get payPriceRefreshIn => 'Der Preis wird aktualisiert in ';

  @override
  String get payWhichWallet => 'Aus welcher Wallet möchten Sie bezahlen?';

  @override
  String get payExternalWalletDescription =>
      'Von einer anderen Bitcoin-Wallet bezahlen';

  @override
  String get payRbfActivated => 'Gebührenerhöhung aktiviert';

  @override
  String get copyDialogButton => 'Kopieren';

  @override
  String get closeDialogButton => 'Schließen';

  @override
  String get sellCompleteKYC => 'KYC abschließen';

  @override
  String get sellSendPaymentNetworkFees => 'Netzwerkgebühren';

  @override
  String get sellSendPaymentContinue => 'Fortfahren';

  @override
  String get exchangeSendingPayment => 'Zahlung wird gesendet…';

  @override
  String get exchangePaymentSentRefreshingOrder =>
      'Zahlung gesendet, Ihre Bestellung wird aktualisiert…';

  @override
  String get sellBitcoinPriceLabel => 'Bitcoin-Preis';

  @override
  String get sellViewDetailsButton => 'Details anzeigen';

  @override
  String get sellKycPendingTitle => 'KYC-Identitätsprüfung ausstehend';

  @override
  String get sellKycPendingDescription =>
      'Sie müssen zuerst die Identitätsprüfung abschließen.';

  @override
  String get sellLoadingGeneric => 'Wird geladen…';

  @override
  String get viewerTapToCopy => 'Zum Kopieren tippen';

  @override
  String get invoiceViewerTitle => 'Rechnung';

  @override
  String get payjoinViaPayjoin => 'über Payjoin';

  @override
  String get payjoinViaRegularSend => 'per regulärer Transaktion';

  @override
  String get sellDepositAddress => 'Einzahlungsadresse';

  @override
  String get payDepositAddress => 'Einzahlungsadresse';

  @override
  String get sellDepositAddressChangedError =>
      'Die Einzahlungsadresse dieses Auftrags hat sich unerwartet geändert. Senden Sie zu Ihrer Sicherheit keine Zahlung für diesen Auftrag. Gehen Sie zurück und erstellen Sie einen neuen Auftrag.';

  @override
  String get payDepositAddressChangedError =>
      'Die Einzahlungsadresse dieses Auftrags hat sich unerwartet geändert. Senden Sie zu Ihrer Sicherheit keine Zahlung für diesen Auftrag. Gehen Sie zurück und erstellen Sie einen neuen Auftrag.';

  @override
  String get sellUnexpectedError =>
      'Ihre Verkaufsorder konnte derzeit nicht abgeschlossen werden. Bitte versuchen Sie es erneut oder wenden Sie sich an den Support.';

  @override
  String get sellErrorFeeBelowRelayFloor =>
      'Netzwerkgebühr zu niedrig. Wählen Sie eine höhere Gebühr.';

  @override
  String get sellErrorFeesUnavailable =>
      'Die Netzwerkgebühren konnten nicht geladen werden. Prüfen Sie Ihre Verbindung und versuchen Sie es erneut.';

  @override
  String get payUnexpectedError =>
      'Ihre Zahlung konnte derzeit nicht abgeschlossen werden. Bitte versuchen Sie es erneut oder wenden Sie sich an den Support.';

  @override
  String get payErrorFeeBelowRelayFloor =>
      'Die Netzwerkgebühr ist zu niedrig. Wählen Sie eine höhere Gebühr.';

  @override
  String get payErrorFeesUnavailable =>
      'Die Netzwerkgebühren konnten nicht geladen werden. Prüfen Sie Ihre Verbindung und versuchen Sie es erneut.';

  @override
  String get withdrawRecipientsPrompt =>
      'Wohin und wie sollen wir das Geld senden?';

  @override
  String get copiedToClipboard => 'In die Zwischenablage kopiert';

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
  String get sellPayoutBalance => 'Meinem Kontoguthaben hinzufügen';

  @override
  String get sellPayoutSepaDescription =>
      'Auszahlungen erscheinen als von Leonod gesendet';

  @override
  String get sellPayoutTitle => 'Empfänger auswählen';

  @override
  String get sellPayoutNewBadge => 'NEU';

  @override
  String get walletSpendAwaitingObservation =>
      'Spending is unavailable until this wallet is synced and has seen its previous payments on the network. Refresh the wallet or use Scan for missing transactions, then try again.';

  @override
  String get sendPayjoinSpendPaused =>
      'This Payjoin payment is paused because the wallet cannot safely continue. Its inputs remain reserved. Refresh the wallet or use Scan for missing transactions, then retry this proposal while it is still valid. If it has expired, check the payment in Transactions before taking further action.';

  @override
  String get walletSpendBusy => 'The wallet is busy. Try again in a moment.';

  @override
  String get broadcastSignedTxErrorOutcomeUnknown =>
      'Wir konnten nicht bestätigen, dass Ihre Transaktion gesendet wurde. Prüfen Sie sie in einem Block-Explorer, bevor Sie es erneut versuchen.';

  @override
  String get sendSelectedUtxosInsufficient =>
      'Die ausgewählten UTXOs erreichen den erforderlichen Betrag nicht.';

  @override
  String get selectAmountTitle => 'Betrag auswählen';

  @override
  String amountRequestedLabel(String amount) {
    return 'Betrag beantragt: $amount';
  }

  @override
  String get addressLabel => 'Adresse: ';

  @override
  String get typeLabel => 'Typ:';

  @override
  String get coinsKeychainReceive => 'Empfangen';

  @override
  String get coinsKeychainChange => 'Wechselgeld';
}
