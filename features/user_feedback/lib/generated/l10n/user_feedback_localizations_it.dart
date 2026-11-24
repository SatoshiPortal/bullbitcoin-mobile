// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'user_feedback_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class UserFeedbackLocalizationsIt extends UserFeedbackLocalizations {
  UserFeedbackLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get feedbackTitle => 'Invia feedback';

  @override
  String get feedbackClose => 'Chiudi';

  @override
  String get feedbackLoadError =>
      'Impossibile caricare il modulo. Controlla la connessione e riprova.';

  @override
  String get feedbackRetry => 'Riprova';

  @override
  String get feedbackShakeTitle => 'Qualcosa non va?';

  @override
  String get feedbackShakeBody =>
      'Invia al team una segnalazione di bug o un\'idea.';

  @override
  String get feedbackShakeDismiss => 'Non ora';

  @override
  String get feedbackSearchKeywords =>
      'feedback, bug, segnalazione, idea, suggerimento, problema, contatto';
}
