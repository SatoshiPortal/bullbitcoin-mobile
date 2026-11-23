// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'exchange_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class ExchangeLocalizationsUk extends ExchangeLocalizations {
  ExchangeLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get exchangeSupportChatAttachFileTooltip => 'Attach a file';

  @override
  String get exchangeSupportChatAttachLogsFailed =>
      'Не вдалося прикріпити журнали. Спробуйте ще раз.';

  @override
  String get exchangeSupportChatAttachLogsTooltip => 'Attach logs';

  @override
  String get exchangeSupportChatAttachmentImage => 'Зображення';

  @override
  String get exchangeSupportChatAttachmentUnknownFile => 'Невідомий файл';

  @override
  String get exchangeSupportChatEmptyState =>
      'Немає повідомлень. Почати розмову!';

  @override
  String get exchangeSupportChatFetchFileDataFailed =>
      'Не вдалося отримати дані файлу.';

  @override
  String get exchangeSupportChatInputHint => 'Тип повідомлення...';

  @override
  String get exchangeSupportChatLoadAttachmentError =>
      'Не вдалося відкрити вкладення. Спробуйте ще раз.';

  @override
  String get exchangeSupportChatLoadMessagesError =>
      'Не вдалося завантажити повідомлення. Спробуйте ще раз.';

  @override
  String get exchangeSupportChatMessageEmptyError =>
      'Повідомлення не може бути порожнім';

  @override
  String get exchangeSupportChatMessageRequired => 'Необхідне повідомлення';

  @override
  String get exchangeSupportChatPickFilesFailed =>
      'Не вдалося вибрати файли. Спробуйте ще раз.';

  @override
  String get exchangeSupportChatSendMessageError =>
      'Не вдалося надіслати повідомлення. Спробуйте ще раз.';

  @override
  String get exchangeSupportChatSendTooltip => 'Send message';

  @override
  String get exchangeSupportChatTitle => 'Підтримка чату';

  @override
  String get exchangeSupportChatYesterday => 'Погода';

  @override
  String get exchangeSupportLoginChatRequired =>
      'Щоб отримати підтримку від живого оператора, спершу потрібно увійти у свій обліковий запис Bull Bitcoin. Це абсолютно безкоштовно, KYC не потрібен — лише адреса електронної пошти.';

  @override
  String get oopsSomethingWentWrong => 'Опери Хтось пішов неправильно';

  @override
  String get exchangeSupportChatLogDraft => 'Here are my logs';
}
