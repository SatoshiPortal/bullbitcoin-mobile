// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'exchange_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class ExchangeLocalizationsRu extends ExchangeLocalizations {
  ExchangeLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get exchangeSupportChatAttachFileTooltip => 'Attach a file';

  @override
  String get exchangeSupportChatAttachLogsFailed =>
      'Не удалось прикрепить журналы. Попробуйте снова.';

  @override
  String get exchangeSupportChatAttachLogsTooltip => 'Attach logs';

  @override
  String get exchangeSupportChatAttachmentImage => 'Изображение';

  @override
  String get exchangeSupportChatAttachmentUnknownFile => 'Неизвестный файл';

  @override
  String get exchangeSupportChatEmptyState =>
      'Пока никаких сообщений. Начинайте разговор!';

  @override
  String get exchangeSupportChatFetchFileDataFailed =>
      'Не удалось получить данные файла.';

  @override
  String get exchangeSupportChatInputHint => 'Введите сообщение...';

  @override
  String get exchangeSupportChatLoadAttachmentError =>
      'Не удалось открыть вложение. Попробуйте ещё раз.';

  @override
  String get exchangeSupportChatLoadMessagesError =>
      'Не удалось загрузить сообщения. Попробуйте ещё раз.';

  @override
  String get exchangeSupportChatMessageEmptyError =>
      'Сообщение не может быть пустым';

  @override
  String get exchangeSupportChatMessageRequired => 'Требуется сообщение';

  @override
  String get exchangeSupportChatPickFilesFailed =>
      'Не удалось выбрать файлы. Попробуйте снова.';

  @override
  String get exchangeSupportChatSendMessageError =>
      'Не удалось отправить сообщение. Попробуйте ещё раз.';

  @override
  String get exchangeSupportChatSendTooltip => 'Send message';

  @override
  String get exchangeSupportChatTitle => 'Поддержка чат';

  @override
  String get exchangeSupportChatYesterday => 'Вчера';

  @override
  String get exchangeSupportLoginChatRequired =>
      'Чтобы получить поддержку от живого оператора, необходимо сначала войти в свой аккаунт Bull Bitcoin. Это полностью бесплатно, KYC не требуется — только адрес электронной почты.';

  @override
  String get oopsSomethingWentWrong => 'Упс! Что-то не так';

  @override
  String get exchangeSupportChatLogDraft => 'Here are my logs';
}
