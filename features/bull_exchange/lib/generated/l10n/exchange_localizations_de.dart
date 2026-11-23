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
}
