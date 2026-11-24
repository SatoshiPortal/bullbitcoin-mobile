// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'user_feedback_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class UserFeedbackLocalizationsEn extends UserFeedbackLocalizations {
  UserFeedbackLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get feedbackTitle => 'Send feedback';

  @override
  String get feedbackClose => 'Close';

  @override
  String get feedbackLoadError =>
      'Couldn\'t load the feedback form. Check your connection and try again.';

  @override
  String get feedbackRetry => 'Try again';

  @override
  String get feedbackShakeTitle => 'Something not right?';

  @override
  String get feedbackShakeBody => 'Send the team a bug report or an idea.';

  @override
  String get feedbackShakeDismiss => 'Not now';

  @override
  String get feedbackSearchKeywords =>
      'feedback, bug, report, idea, suggestion, problem, contact';
}
