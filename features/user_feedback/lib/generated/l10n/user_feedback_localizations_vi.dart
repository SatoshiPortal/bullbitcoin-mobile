// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'user_feedback_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class UserFeedbackLocalizationsVi extends UserFeedbackLocalizations {
  UserFeedbackLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get feedbackTitle => 'Gửi phản hồi';

  @override
  String get feedbackClose => 'Đóng';

  @override
  String get feedbackLoadError =>
      'Không tải được biểu mẫu. Hãy kiểm tra kết nối và thử lại.';

  @override
  String get feedbackRetry => 'Thử lại';

  @override
  String get feedbackShakeTitle => 'Có gì không ổn?';

  @override
  String get feedbackShakeBody => 'Gửi cho đội ngũ báo cáo lỗi hoặc ý tưởng.';

  @override
  String get feedbackShakeDismiss => 'Để sau';

  @override
  String get feedbackSearchKeywords =>
      'phản hồi, lỗi, báo cáo, ý tưởng, đề xuất, vấn đề, liên hệ';
}
