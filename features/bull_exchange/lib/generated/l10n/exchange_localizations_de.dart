// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'exchange_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class ExchangeLocalizationsDe extends ExchangeLocalizations {
  ExchangeLocalizationsDe([String locale = 'de']) : super(locale);

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
  String get oopsSomethingWentWrong => 'Ups! Etwas ist schief gelaufen';

  @override
  String get exchangeSupportChatLogDraft => 'Here are my logs';
}
