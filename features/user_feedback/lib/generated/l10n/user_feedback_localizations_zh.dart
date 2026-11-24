// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'user_feedback_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class UserFeedbackLocalizationsZh extends UserFeedbackLocalizations {
  UserFeedbackLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get feedbackTitle => '发送反馈';

  @override
  String get feedbackClose => '关闭';

  @override
  String get feedbackLoadError => '无法加载反馈表单。请检查网络连接后重试。';

  @override
  String get feedbackRetry => '重试';

  @override
  String get feedbackShakeTitle => '遇到问题了？';

  @override
  String get feedbackShakeBody => '向团队报告错误或分享想法。';

  @override
  String get feedbackShakeDismiss => '以后再说';

  @override
  String get feedbackSearchKeywords => '反馈, 错误, 漏洞, 报告, 想法, 建议, 问题, 联系';
}
