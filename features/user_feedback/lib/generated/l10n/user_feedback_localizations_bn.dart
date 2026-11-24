// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'user_feedback_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class UserFeedbackLocalizationsBn extends UserFeedbackLocalizations {
  UserFeedbackLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get feedbackTitle => 'মতামত পাঠান';

  @override
  String get feedbackClose => 'বন্ধ করুন';

  @override
  String get feedbackLoadError =>
      'ফর্মটি লোড করা যায়নি। সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।';

  @override
  String get feedbackRetry => 'আবার চেষ্টা করুন';

  @override
  String get feedbackShakeTitle => 'কিছু ঠিক নেই?';

  @override
  String get feedbackShakeBody => 'টিমকে একটি বাগ রিপোর্ট বা আইডিয়া পাঠান।';

  @override
  String get feedbackShakeDismiss => 'এখন নয়';

  @override
  String get feedbackSearchKeywords =>
      'মতামত, বাগ, রিপোর্ট, আইডিয়া, পরামর্শ, সমস্যা, যোগাযোগ';
}
