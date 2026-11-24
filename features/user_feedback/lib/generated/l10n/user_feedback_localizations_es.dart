// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'user_feedback_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class UserFeedbackLocalizationsEs extends UserFeedbackLocalizations {
  UserFeedbackLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get feedbackTitle => 'Enviar comentarios';

  @override
  String get feedbackClose => 'Cerrar';

  @override
  String get feedbackLoadError =>
      'No se pudo cargar el formulario. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get feedbackRetry => 'Reintentar';

  @override
  String get feedbackShakeTitle => '¿Algo no va bien?';

  @override
  String get feedbackShakeBody =>
      'Envía al equipo un informe de error o una idea.';

  @override
  String get feedbackShakeDismiss => 'Ahora no';

  @override
  String get feedbackSearchKeywords =>
      'comentarios, error, informe, idea, sugerencia, problema, contacto';
}
