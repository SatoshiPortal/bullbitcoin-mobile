// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'user_feedback_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Armenian (`hy`).
class UserFeedbackLocalizationsHy extends UserFeedbackLocalizations {
  UserFeedbackLocalizationsHy([String locale = 'hy']) : super(locale);

  @override
  String get feedbackTitle => 'Ուղարկել կարծիք';

  @override
  String get feedbackClose => 'Փակել';

  @override
  String get feedbackLoadError =>
      'Չհաջողվեց բեռնել ձևը։ Ստուգեք կապը և նորից փորձեք։';

  @override
  String get feedbackRetry => 'Կրկին փորձել';

  @override
  String get feedbackShakeTitle => 'Ինչ-որ բան այն չէ՞';

  @override
  String get feedbackShakeBody =>
      'Ուղարկեք թիմին սխալի հաշվետվություն կամ գաղափար։';

  @override
  String get feedbackShakeDismiss => 'Ոչ հիմա';

  @override
  String get feedbackSearchKeywords =>
      'կարծիք, սխալ, բագ, հաշվետվություն, գաղափար, առաջարկ, խնդիր, կապ';
}
