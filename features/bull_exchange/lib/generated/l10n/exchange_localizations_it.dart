// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'exchange_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class ExchangeLocalizationsIt extends ExchangeLocalizations {
  ExchangeLocalizationsIt([String locale = 'it']) : super(locale);

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
  String get oopsSomethingWentWrong => 'Ops! Qualcosa non va';

  @override
  String get exchangeSupportChatLogDraft => 'Here are my logs';
}
