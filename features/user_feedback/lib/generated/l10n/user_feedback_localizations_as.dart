// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'user_feedback_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Assamese (`as`).
class UserFeedbackLocalizationsAs extends UserFeedbackLocalizations {
  UserFeedbackLocalizationsAs([String locale = 'as']) : super(locale);

  @override
  String get feedbackTitle => 'মতামত পঠিয়াওক';

  @override
  String get feedbackClose => 'বন্ধ কৰক';

  @override
  String get feedbackLoadError =>
      'ফৰ্মখন ল\'ড কৰিব পৰা নগ\'ল। সংযোগ পৰীক্ষা কৰি পুনৰ চেষ্টা কৰক।';

  @override
  String get feedbackRetry => 'পুনৰ চেষ্টা কৰক';

  @override
  String get feedbackShakeTitle => 'কিবা ঠিক নাই নেকি?';

  @override
  String get feedbackShakeBody =>
      'দলটোলৈ বাগ ৰিপ\'ৰ্ট বা কোনো আইডিয়া পঠিয়াওক।';

  @override
  String get feedbackShakeDismiss => 'এতিয়া নহয়';

  @override
  String get feedbackSearchKeywords =>
      'মতামত, বাগ, ৰিপ\'ৰ্ট, আইডিয়া, পৰামৰ্শ, সমস্যা, যোগাযোগ';
}
