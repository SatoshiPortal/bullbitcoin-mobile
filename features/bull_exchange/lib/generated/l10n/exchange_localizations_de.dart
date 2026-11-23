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
