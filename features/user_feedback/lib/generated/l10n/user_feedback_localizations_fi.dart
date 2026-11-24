// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'user_feedback_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Finnish (`fi`).
class UserFeedbackLocalizationsFi extends UserFeedbackLocalizations {
  UserFeedbackLocalizationsFi([String locale = 'fi']) : super(locale);

  @override
  String get feedbackTitle => 'Lähetä palautetta';

  @override
  String get feedbackClose => 'Sulje';

  @override
  String get feedbackLoadError =>
      'Lomaketta ei voitu ladata. Tarkista yhteys ja yritä uudelleen.';

  @override
  String get feedbackRetry => 'Yritä uudelleen';

  @override
  String get feedbackShakeTitle => 'Jokin vialla?';

  @override
  String get feedbackShakeBody => 'Lähetä tiimille virheraportti tai idea.';

  @override
  String get feedbackShakeDismiss => 'Ei nyt';

  @override
  String get feedbackSearchKeywords =>
      'palaute, virhe, bugi, raportti, idea, ehdotus, ongelma, yhteys';
}
