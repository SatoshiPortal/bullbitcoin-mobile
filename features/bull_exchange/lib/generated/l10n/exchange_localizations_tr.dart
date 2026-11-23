// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'exchange_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class ExchangeLocalizationsTr extends ExchangeLocalizations {
  ExchangeLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get exchangeSupportChatAttachFileTooltip => 'Attach a file';

  @override
  String get exchangeSupportChatAttachLogsFailed =>
      'Günlükler eklenemedi. Lütfen tekrar deneyin.';

  @override
  String get exchangeSupportChatAttachLogsTooltip => 'Attach logs';

  @override
  String get exchangeSupportChatAttachmentImage => 'Görsel';

  @override
  String get exchangeSupportChatAttachmentUnknownFile => 'Bilinmeyen dosya';

  @override
  String get exchangeSupportChatEmptyState =>
      'Henüz mesajlar yok. Bir sohbete başlayın!';

  @override
  String get exchangeSupportChatFetchFileDataFailed => 'Dosya verisi alınamadı';

  @override
  String get exchangeSupportChatInputHint => 'Bir mesaj yazın...';

  @override
  String get exchangeSupportChatLoadAttachmentError =>
      'Ek açılamadı. Lütfen tekrar deneyin.';

  @override
  String get exchangeSupportChatLoadMessagesError =>
      'Mesajlar yüklenemedi. Lütfen tekrar deneyin.';

  @override
  String get exchangeSupportChatMessageEmptyError => 'Mesaj boş olamaz';

  @override
  String get exchangeSupportChatMessageRequired => 'Bir mesaj gereklidir';

  @override
  String get exchangeSupportChatPickFilesFailed =>
      'Dosyalar seçilemedi. Lütfen tekrar deneyin.';

  @override
  String get exchangeSupportChatSendMessageError =>
      'Mesajınız gönderilemedi. Lütfen tekrar deneyin.';

  @override
  String get exchangeSupportChatSendTooltip => 'Send message';

  @override
  String get exchangeSupportChatTitle => 'Destek Chat';

  @override
  String get exchangeSupportChatYesterday => 'Dün';

  @override
  String get exchangeSupportLoginChatRequired =>
      'Canlı destek almak için önce Bull Bitcoin hesabınıza giriş yapmanız gerekir. Tamamen ücretsizdir ve KYC gerekmez, sadece bir e-posta adresi yeterlidir.';

  @override
  String get oopsSomethingWentWrong =>
      'Oops! Bir şey ters gitti yanlış bir şey gitti';

  @override
  String get exchangeSupportChatLogDraft => 'Here are my logs';
}
