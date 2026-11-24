// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'user_feedback_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class UserFeedbackLocalizationsHi extends UserFeedbackLocalizations {
  UserFeedbackLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get feedbackTitle => 'फ़ीडबैक भेजें';

  @override
  String get feedbackClose => 'बंद करें';

  @override
  String get feedbackLoadError =>
      'फ़ॉर्म लोड नहीं हो सका। अपना कनेक्शन जाँचें और फिर से कोशिश करें।';

  @override
  String get feedbackRetry => 'फिर से कोशिश करें';

  @override
  String get feedbackShakeTitle => 'कुछ ठीक नहीं है?';

  @override
  String get feedbackShakeBody => 'टीम को बग रिपोर्ट या कोई सुझाव भेजें।';

  @override
  String get feedbackShakeDismiss => 'अभी नहीं';

  @override
  String get feedbackSearchKeywords =>
      'फ़ीडबैक, बग, रिपोर्ट, सुझाव, विचार, समस्या, संपर्क';
}

/// The translations for Hindi, using the Latin script (`hi_Latn`).
class UserFeedbackLocalizationsHiLatn extends UserFeedbackLocalizationsHi {
  UserFeedbackLocalizationsHiLatn() : super('hi_Latn');

  @override
  String get feedbackTitle => 'Feedback bhejein';

  @override
  String get feedbackClose => 'Band karein';

  @override
  String get feedbackLoadError =>
      'Form load nahin ho saka. Apna connection check karein aur phir se koshish karein.';

  @override
  String get feedbackRetry => 'Phir se koshish karein';

  @override
  String get feedbackShakeTitle => 'Kuch theek nahin hai?';

  @override
  String get feedbackShakeBody => 'Team ko bug report ya koi idea bhejein.';

  @override
  String get feedbackShakeDismiss => 'Abhi nahin';

  @override
  String get feedbackSearchKeywords =>
      'feedback, bug, report, idea, sujhav, samasya, sampark';
}
