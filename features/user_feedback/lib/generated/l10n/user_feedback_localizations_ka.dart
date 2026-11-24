// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'user_feedback_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Georgian (`ka`).
class UserFeedbackLocalizationsKa extends UserFeedbackLocalizations {
  UserFeedbackLocalizationsKa([String locale = 'ka']) : super(locale);

  @override
  String get feedbackTitle => 'გამოხმაურების გაგზავნა';

  @override
  String get feedbackClose => 'დახურვა';

  @override
  String get feedbackLoadError =>
      'ფორმის ჩატვირთვა ვერ მოხერხდა. შეამოწმეთ კავშირი და სცადეთ ხელახლა.';

  @override
  String get feedbackRetry => 'ხელახლა ცდა';

  @override
  String get feedbackShakeTitle => 'რამე არ არის რიგზე?';

  @override
  String get feedbackShakeBody => 'გაუგზავნეთ გუნდს შეცდომის ანგარიში ან იდეა.';

  @override
  String get feedbackShakeDismiss => 'ახლა არა';

  @override
  String get feedbackSearchKeywords =>
      'გამოხმაურება, შეცდომა, ბაგი, ანგარიში, იდეა, შეთავაზება, პრობლემა, კონტაქტი';
}
