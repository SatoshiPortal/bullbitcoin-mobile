// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'user_feedback_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class UserFeedbackLocalizationsKo extends UserFeedbackLocalizations {
  UserFeedbackLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get feedbackTitle => '피드백 보내기';

  @override
  String get feedbackClose => '닫기';

  @override
  String get feedbackLoadError => '양식을 불러오지 못했습니다. 연결을 확인하고 다시 시도하세요.';

  @override
  String get feedbackRetry => '다시 시도';

  @override
  String get feedbackShakeTitle => '문제가 있나요?';

  @override
  String get feedbackShakeBody => '팀에 버그 신고나 아이디어를 보내 주세요.';

  @override
  String get feedbackShakeDismiss => '나중에';

  @override
  String get feedbackSearchKeywords => '피드백, 버그, 신고, 아이디어, 제안, 문제, 문의';
}
