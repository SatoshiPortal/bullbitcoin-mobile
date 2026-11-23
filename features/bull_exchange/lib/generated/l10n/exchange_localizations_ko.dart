// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'exchange_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class ExchangeLocalizationsKo extends ExchangeLocalizations {
  ExchangeLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get exchangeSupportChatAttachFileTooltip => 'Attach a file';

  @override
  String get exchangeSupportChatAttachLogsFailed =>
      '로그 첨부에 실패했습니다. 다시 시도해 주세요.';

  @override
  String get exchangeSupportChatAttachLogsTooltip => 'Attach logs';

  @override
  String get exchangeSupportChatAttachmentImage => '이미지';

  @override
  String get exchangeSupportChatAttachmentUnknownFile => '알 수 없는 파일';

  @override
  String get exchangeSupportChatEmptyState => '아직 메시지가 없습니다. 대화 시작!';

  @override
  String get exchangeSupportChatFetchFileDataFailed => '파일 데이터를 가져오지 못했습니다';

  @override
  String get exchangeSupportChatInputHint => '이름 *.';

  @override
  String get exchangeSupportChatLoadAttachmentError =>
      '첨부 파일을 열지 못했습니다. 다시 시도해 주세요.';

  @override
  String get exchangeSupportChatLoadMessagesError =>
      '메시지를 불러오지 못했습니다. 다시 시도해 주세요.';

  @override
  String get exchangeSupportChatMessageEmptyError => '메시지가 비어있을 수 없습니다';

  @override
  String get exchangeSupportChatMessageRequired => '자주 묻는 질문';

  @override
  String get exchangeSupportChatPickFilesFailed =>
      '파일을 선택하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get exchangeSupportChatSendMessageError =>
      '메시지를 보내지 못했습니다. 다시 시도해 주세요.';

  @override
  String get exchangeSupportChatSendTooltip => 'Send message';

  @override
  String get exchangeSupportChatTitle => '지원 채팅';

  @override
  String get exchangeSupportChatYesterday => '1 년 전';

  @override
  String get exchangeSupportLoginChatRequired =>
      '실시간 지원을 받으려면 먼저 Bull Bitcoin 계정에 로그인해야 합니다. 완전 무료이며 KYC가 필요하지 않고, 이메일 주소만 있으면 됩니다.';

  @override
  String get oopsSomethingWentWrong => '인기 있는 뭔가 잘못되었습니다';

  @override
  String get exchangeSupportChatLogDraft => 'Here are my logs';
}
