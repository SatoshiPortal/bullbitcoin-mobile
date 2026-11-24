// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'user_feedback_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class UserFeedbackLocalizationsTr extends UserFeedbackLocalizations {
  UserFeedbackLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get feedbackTitle => 'Geri bildirim gönder';

  @override
  String get feedbackClose => 'Kapat';

  @override
  String get feedbackLoadError =>
      'Form yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.';

  @override
  String get feedbackRetry => 'Tekrar dene';

  @override
  String get feedbackShakeTitle => 'Bir sorun mu var?';

  @override
  String get feedbackShakeBody =>
      'Ekibe bir hata bildirimi veya fikir gönderin.';

  @override
  String get feedbackShakeDismiss => 'Şimdi değil';

  @override
  String get feedbackSearchKeywords =>
      'geri bildirim, hata, bug, bildir, fikir, öneri, sorun, iletişim';
}
