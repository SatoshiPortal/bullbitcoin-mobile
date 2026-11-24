// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'user_feedback_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swahili (`sw`).
class UserFeedbackLocalizationsSw extends UserFeedbackLocalizations {
  UserFeedbackLocalizationsSw([String locale = 'sw']) : super(locale);

  @override
  String get feedbackTitle => 'Tuma maoni';

  @override
  String get feedbackClose => 'Funga';

  @override
  String get feedbackLoadError =>
      'Imeshindwa kupakia fomu. Angalia muunganisho wako kisha ujaribu tena.';

  @override
  String get feedbackRetry => 'Jaribu tena';

  @override
  String get feedbackShakeTitle => 'Kuna tatizo?';

  @override
  String get feedbackShakeBody => 'Tuma kwa timu ripoti ya hitilafu au wazo.';

  @override
  String get feedbackShakeDismiss => 'Si sasa';

  @override
  String get feedbackSearchKeywords =>
      'maoni, hitilafu, ripoti, wazo, pendekezo, tatizo, mawasiliano';
}
