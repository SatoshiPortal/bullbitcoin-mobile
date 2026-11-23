// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'exchange_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bulgarian (`bg`).
class ExchangeLocalizationsBg extends ExchangeLocalizations {
  ExchangeLocalizationsBg([String locale = 'bg']) : super(locale);

  @override
  String get exchangeSupportChatAttachFileTooltip => 'Attach a file';

  @override
  String get exchangeSupportChatAttachLogsFailed =>
      'Прикачването на регистри не успя. Моля, опитайте отново.';

  @override
  String get exchangeSupportChatAttachLogsTooltip => 'Attach logs';

  @override
  String get exchangeSupportChatAttachmentImage => 'Изображение';

  @override
  String get exchangeSupportChatAttachmentUnknownFile => 'Неизвестен файл';

  @override
  String get exchangeSupportChatEmptyState =>
      'Все още няма съобщения. Започнете разговор!';

  @override
  String get exchangeSupportChatFetchFileDataFailed =>
      'Извличането на данните от файла не успя.';

  @override
  String get exchangeSupportChatInputHint => 'Напишете съобщение...';

  @override
  String get exchangeSupportChatLoadAttachmentError =>
      'Прикаченият файл не можа да бъде отворен. Моля, опитайте отново.';

  @override
  String get exchangeSupportChatLoadMessagesError =>
      'Съобщенията не могат да бъдат заредени. Моля, опитайте отново.';

  @override
  String get exchangeSupportChatMessageEmptyError =>
      'Съобщението не може да бъде празно';

  @override
  String get exchangeSupportChatMessageRequired => 'Изисква се съобщение';

  @override
  String get exchangeSupportChatPickFilesFailed =>
      'Изборът на файлове не успя. Моля, опитайте отново.';

  @override
  String get exchangeSupportChatSendMessageError =>
      'Съобщението ви не можа да бъде изпратено. Моля, опитайте отново.';

  @override
  String get exchangeSupportChatSendTooltip => 'Send message';

  @override
  String get exchangeSupportChatTitle => 'Чат за поддръжка';

  @override
  String get exchangeSupportChatYesterday => 'Вчера';

  @override
  String get exchangeSupportLoginChatRequired =>
      'За да получите помощ от жив оператор, първо трябва да влезете в акаунта си в Bull Bitcoin. Напълно безплатно е и не се изисква KYC, само имейл адрес.';

  @override
  String get oopsSomethingWentWrong => 'Опа! Нещо се обърка';

  @override
  String get exchangeSupportChatLogDraft => 'Here are my logs';
}
