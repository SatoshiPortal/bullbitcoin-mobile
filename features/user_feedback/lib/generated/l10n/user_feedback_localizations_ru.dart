// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'user_feedback_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class UserFeedbackLocalizationsRu extends UserFeedbackLocalizations {
  UserFeedbackLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get feedbackTitle => 'Отправить отзыв';

  @override
  String get feedbackClose => 'Закрыть';

  @override
  String get feedbackLoadError =>
      'Не удалось загрузить форму. Проверьте подключение и попробуйте снова.';

  @override
  String get feedbackRetry => 'Повторить';

  @override
  String get feedbackShakeTitle => 'Что-то не так?';

  @override
  String get feedbackShakeBody =>
      'Отправьте команде сообщение об ошибке или идею.';

  @override
  String get feedbackShakeDismiss => 'Не сейчас';

  @override
  String get feedbackSearchKeywords =>
      'отзыв, ошибка, баг, сообщить, идея, предложение, проблема, контакт';
}
