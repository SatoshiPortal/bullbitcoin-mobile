// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'user_feedback_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class UserFeedbackLocalizationsTh extends UserFeedbackLocalizations {
  UserFeedbackLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get feedbackTitle => 'ส่งความคิดเห็น';

  @override
  String get feedbackClose => 'ปิด';

  @override
  String get feedbackLoadError =>
      'โหลดแบบฟอร์มไม่ได้ ตรวจสอบการเชื่อมต่อแล้วลองอีกครั้ง';

  @override
  String get feedbackRetry => 'ลองอีกครั้ง';

  @override
  String get feedbackShakeTitle => 'มีอะไรผิดปกติไหม?';

  @override
  String get feedbackShakeBody => 'ส่งรายงานข้อผิดพลาดหรือไอเดียให้ทีม';

  @override
  String get feedbackShakeDismiss => 'ไว้ทีหลัง';

  @override
  String get feedbackSearchKeywords =>
      'ความคิดเห็น, บั๊ก, รายงาน, ไอเดีย, ข้อเสนอแนะ, ปัญหา, ติดต่อ';
}
