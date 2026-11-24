// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'user_feedback_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class UserFeedbackLocalizationsAr extends UserFeedbackLocalizations {
  UserFeedbackLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get feedbackTitle => 'إرسال ملاحظات';

  @override
  String get feedbackClose => 'إغلاق';

  @override
  String get feedbackLoadError =>
      'تعذّر تحميل النموذج. تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get feedbackRetry => 'إعادة المحاولة';

  @override
  String get feedbackShakeTitle => 'هل هناك مشكلة؟';

  @override
  String get feedbackShakeBody => 'أرسل إلى الفريق بلاغًا عن خطأ أو فكرة.';

  @override
  String get feedbackShakeDismiss => 'ليس الآن';

  @override
  String get feedbackSearchKeywords =>
      'ملاحظات, خطأ, بلاغ, فكرة, اقتراح, مشكلة, تواصل';
}
