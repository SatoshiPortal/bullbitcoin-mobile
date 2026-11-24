// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'user_feedback_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bulgarian (`bg`).
class UserFeedbackLocalizationsBg extends UserFeedbackLocalizations {
  UserFeedbackLocalizationsBg([String locale = 'bg']) : super(locale);

  @override
  String get feedbackTitle => 'Изпрати отзив';

  @override
  String get feedbackClose => 'Затвори';

  @override
  String get feedbackLoadError =>
      'Формулярът не можа да се зареди. Проверете връзката си и опитайте отново.';

  @override
  String get feedbackRetry => 'Опитай отново';

  @override
  String get feedbackShakeTitle => 'Нещо не е наред?';

  @override
  String get feedbackShakeBody =>
      'Изпратете на екипа доклад за грешка или идея.';

  @override
  String get feedbackShakeDismiss => 'Не сега';

  @override
  String get feedbackSearchKeywords =>
      'отзив, грешка, бъг, доклад, идея, предложение, проблем, контакт';
}
