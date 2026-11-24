// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'user_feedback_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class UserFeedbackLocalizationsUk extends UserFeedbackLocalizations {
  UserFeedbackLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get feedbackTitle => 'Надіслати відгук';

  @override
  String get feedbackClose => 'Закрити';

  @override
  String get feedbackLoadError =>
      'Не вдалося завантажити форму. Перевірте з\'єднання та спробуйте ще раз.';

  @override
  String get feedbackRetry => 'Спробувати ще раз';

  @override
  String get feedbackShakeTitle => 'Щось не так?';

  @override
  String get feedbackShakeBody =>
      'Надішліть команді звіт про помилку або ідею.';

  @override
  String get feedbackShakeDismiss => 'Не зараз';

  @override
  String get feedbackSearchKeywords =>
      'відгук, помилка, баг, повідомити, ідея, пропозиція, проблема, контакт';
}
