// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'user_feedback_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class UserFeedbackLocalizationsFr extends UserFeedbackLocalizations {
  UserFeedbackLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get feedbackTitle => 'Envoyer un commentaire';

  @override
  String get feedbackClose => 'Fermer';

  @override
  String get feedbackLoadError =>
      'Impossible de charger le formulaire. Vérifiez votre connexion et réessayez.';

  @override
  String get feedbackRetry => 'Réessayer';

  @override
  String get feedbackShakeTitle => 'Un problème ?';

  @override
  String get feedbackShakeBody =>
      'Envoyez à l\'équipe un rapport de bug ou une idée.';

  @override
  String get feedbackShakeDismiss => 'Plus tard';

  @override
  String get feedbackSearchKeywords =>
      'commentaire, bug, signaler, idée, suggestion, problème, contact';
}
