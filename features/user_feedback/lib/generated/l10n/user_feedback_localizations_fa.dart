// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'user_feedback_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class UserFeedbackLocalizationsFa extends UserFeedbackLocalizations {
  UserFeedbackLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get feedbackTitle => 'ارسال بازخورد';

  @override
  String get feedbackClose => 'بستن';

  @override
  String get feedbackLoadError =>
      'فرم بارگیری نشد. اتصال خود را بررسی کنید و دوباره تلاش کنید.';

  @override
  String get feedbackRetry => 'تلاش دوباره';

  @override
  String get feedbackShakeTitle => 'مشکلی هست؟';

  @override
  String get feedbackShakeBody => 'گزارش خطا یا ایده‌ای برای تیم بفرستید.';

  @override
  String get feedbackShakeDismiss => 'الان نه';

  @override
  String get feedbackSearchKeywords =>
      'بازخورد, خطا, باگ, گزارش, ایده, پیشنهاد, مشکل, تماس';
}
