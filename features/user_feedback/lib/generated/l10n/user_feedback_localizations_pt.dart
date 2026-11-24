// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'user_feedback_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class UserFeedbackLocalizationsPt extends UserFeedbackLocalizations {
  UserFeedbackLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get feedbackTitle => 'Enviar feedback';

  @override
  String get feedbackClose => 'Fechar';

  @override
  String get feedbackLoadError =>
      'Não foi possível carregar o formulário. Verifique a sua ligação e tente novamente.';

  @override
  String get feedbackRetry => 'Tentar novamente';

  @override
  String get feedbackShakeTitle => 'Algo não está bem?';

  @override
  String get feedbackShakeBody =>
      'Envie à equipa um relatório de erro ou uma ideia.';

  @override
  String get feedbackShakeDismiss => 'Agora não';

  @override
  String get feedbackSearchKeywords =>
      'feedback, erro, bug, relatório, ideia, sugestão, problema, contacto';
}

/// The translations for Portuguese, as used in Brazil (`pt_BR`).
class UserFeedbackLocalizationsPtBr extends UserFeedbackLocalizationsPt {
  UserFeedbackLocalizationsPtBr() : super('pt_BR');

  @override
  String get feedbackTitle => 'Enviar feedback';

  @override
  String get feedbackClose => 'Fechar';

  @override
  String get feedbackLoadError =>
      'Não foi possível carregar o formulário. Verifique sua conexão e tente novamente.';

  @override
  String get feedbackRetry => 'Tentar novamente';

  @override
  String get feedbackShakeTitle => 'Algo deu errado?';

  @override
  String get feedbackShakeBody =>
      'Envie para a equipe um relato de erro ou uma ideia.';

  @override
  String get feedbackShakeDismiss => 'Agora não';

  @override
  String get feedbackSearchKeywords =>
      'feedback, erro, bug, relato, ideia, sugestão, problema, contato';
}
