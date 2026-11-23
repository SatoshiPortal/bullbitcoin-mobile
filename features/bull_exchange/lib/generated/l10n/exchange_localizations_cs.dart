// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'exchange_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class ExchangeLocalizationsCs extends ExchangeLocalizations {
  ExchangeLocalizationsCs([String locale = 'cs']) : super(locale);

  @override
  String get exchangeSupportChatAttachFileTooltip => 'Attach a file';

  @override
  String get exchangeSupportChatAttachLogsFailed =>
      'Připojení záznamů se nezdařilo. Zkuste to znovu.';

  @override
  String get exchangeSupportChatAttachLogsTooltip => 'Attach logs';

  @override
  String get exchangeSupportChatAttachmentImage => 'Obrázek';

  @override
  String get exchangeSupportChatAttachmentUnknownFile => 'Neznámý soubor';

  @override
  String get exchangeSupportChatEmptyState => 'Žádné zprávy. Začněte rozhovor!';

  @override
  String get exchangeSupportChatFetchFileDataFailed =>
      'Načtení dat souboru se nezdařilo.';

  @override
  String get exchangeSupportChatInputHint => 'Zadejte zprávu...';

  @override
  String get exchangeSupportChatLoadAttachmentError =>
      'Nepodařilo se otevřít přílohu. Zkuste to prosím znovu.';

  @override
  String get exchangeSupportChatLoadMessagesError =>
      'Nepodařilo se načíst zprávy. Zkuste to prosím znovu.';

  @override
  String get exchangeSupportChatMessageEmptyError =>
      'Zpráva nemůže být prázdný';

  @override
  String get exchangeSupportChatMessageRequired => 'Zpráva je nutná';

  @override
  String get exchangeSupportChatPickFilesFailed =>
      'Výběr souborů se nezdařil. Zkuste to znovu.';

  @override
  String get exchangeSupportChatSendMessageError =>
      'Nepodařilo se odeslat zprávu. Zkuste to prosím znovu.';

  @override
  String get exchangeSupportChatSendTooltip => 'Send message';

  @override
  String get exchangeSupportChatTitle => 'Podpora Chat';

  @override
  String get exchangeSupportChatYesterday => 'Včera';

  @override
  String get exchangeSupportLoginChatRequired =>
      'Pro získání lidské podpory se musíte nejprve přihlásit ke svému účtu Bull Bitcoin. Je to zcela zdarma a není vyžadováno žádné KYC, pouze e-mailová adresa.';

  @override
  String get oopsSomethingWentWrong => 'Oops! Něco šlo špatně';

  @override
  String get exchangeSupportChatLogDraft => 'Here are my logs';
}
