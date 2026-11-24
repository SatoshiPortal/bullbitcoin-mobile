// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'user_feedback_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class UserFeedbackLocalizationsCs extends UserFeedbackLocalizations {
  UserFeedbackLocalizationsCs([String locale = 'cs']) : super(locale);

  @override
  String get feedbackTitle => 'Odeslat zpětnou vazbu';

  @override
  String get feedbackClose => 'Zavřít';

  @override
  String get feedbackLoadError =>
      'Formulář se nepodařilo načíst. Zkontrolujte připojení a zkuste to znovu.';

  @override
  String get feedbackRetry => 'Zkusit znovu';

  @override
  String get feedbackShakeTitle => 'Něco není v pořádku?';

  @override
  String get feedbackShakeBody => 'Pošlete týmu hlášení o chybě nebo nápad.';

  @override
  String get feedbackShakeDismiss => 'Teď ne';

  @override
  String get feedbackSearchKeywords =>
      'zpětná vazba, chyba, bug, nahlásit, nápad, návrh, problém, kontakt';
}
