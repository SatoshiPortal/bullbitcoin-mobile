// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'user_feedback_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class UserFeedbackLocalizationsDe extends UserFeedbackLocalizations {
  UserFeedbackLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get feedbackTitle => 'Feedback senden';

  @override
  String get feedbackClose => 'Schließen';

  @override
  String get feedbackLoadError =>
      'Das Formular konnte nicht geladen werden. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get feedbackRetry => 'Erneut versuchen';

  @override
  String get feedbackShakeTitle => 'Stimmt etwas nicht?';

  @override
  String get feedbackShakeBody =>
      'Schicke dem Team einen Fehlerbericht oder eine Idee.';

  @override
  String get feedbackShakeDismiss => 'Nicht jetzt';

  @override
  String get feedbackSearchKeywords =>
      'Feedback, Fehler, Bug, melden, Idee, Vorschlag, Problem, Kontakt';
}
