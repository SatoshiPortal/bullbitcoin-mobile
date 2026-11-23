// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'exchange_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class ExchangeLocalizationsAr extends ExchangeLocalizations {
  ExchangeLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get exchangeSupportChatAttachFileTooltip => 'Attach a file';

  @override
  String get exchangeSupportChatAttachLogsFailed =>
      'فشل إرفاق السجلات. يرجى المحاولة مرة أخرى.';

  @override
  String get exchangeSupportChatAttachLogsTooltip => 'Attach logs';

  @override
  String get exchangeSupportChatAttachmentImage => 'صورة';

  @override
  String get exchangeSupportChatAttachmentUnknownFile => 'ملف غير معروف';

  @override
  String get exchangeSupportChatEmptyState => 'لا رسائل بعد ابدأ المحادثة!';

  @override
  String get exchangeSupportChatFetchFileDataFailed => 'فشل جلب بيانات الملف';

  @override
  String get exchangeSupportChatInputHint => 'اكتب رسالة.';

  @override
  String get exchangeSupportChatLoadAttachmentError =>
      'تعذّر فتح المرفق. يُرجى المحاولة مرة أخرى.';

  @override
  String get exchangeSupportChatLoadMessagesError =>
      'تعذّر تحميل الرسائل. يُرجى المحاولة مرة أخرى.';

  @override
  String get exchangeSupportChatMessageEmptyError =>
      'الرسالة لا يمكن أن تكون فارغة';

  @override
  String get exchangeSupportChatMessageRequired => 'الرسالة مطلوبة';

  @override
  String get exchangeSupportChatPickFilesFailed =>
      'فشل اختيار الملفات. يرجى المحاولة مرة أخرى.';

  @override
  String get exchangeSupportChatSendMessageError =>
      'تعذّر إرسال رسالتك. يُرجى المحاولة مرة أخرى.';

  @override
  String get exchangeSupportChatSendTooltip => 'Send message';

  @override
  String get exchangeSupportChatTitle => 'الدعم';

  @override
  String get exchangeSupportChatYesterday => 'أمس';

  @override
  String get exchangeSupportLoginChatRequired =>
      'للحصول على دعم بشري، يجب عليك أولاً تسجيل الدخول إلى حساب Bull Bitcoin الخاص بك. الخدمة مجانية 100% ولا يتطلب الأمر أي KYC، فقط عنوان بريد إلكتروني.';

  @override
  String get oopsSomethingWentWrong => '! شيء ما حدث';

  @override
  String get exchangeSupportChatLogDraft => 'Here are my logs';
}
