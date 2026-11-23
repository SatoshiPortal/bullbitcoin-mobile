// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'exchange_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class ExchangeLocalizationsZh extends ExchangeLocalizations {
  ExchangeLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get exchangeSupportChatAttachFileTooltip => 'Attach a file';

  @override
  String get exchangeSupportChatAttachLogsFailed => '添加日志失败，请重试。';

  @override
  String get exchangeSupportChatAttachLogsTooltip => 'Attach logs';

  @override
  String get exchangeSupportChatAttachmentImage => '图片';

  @override
  String get exchangeSupportChatAttachmentUnknownFile => '未知文件';

  @override
  String get exchangeSupportChatEmptyState => '尚未发出任何信息。 开始对话!';

  @override
  String get exchangeSupportChatFetchFileDataFailed => '获取文件数据失败';

  @override
  String get exchangeSupportChatInputHint => '信息的类型......';

  @override
  String get exchangeSupportChatLoadAttachmentError => '无法打开附件。请重试。';

  @override
  String get exchangeSupportChatLoadMessagesError => '无法加载消息。请重试。';

  @override
  String get exchangeSupportChatMessageEmptyError => '信息不能空洞';

  @override
  String get exchangeSupportChatMessageRequired => '需要信息';

  @override
  String get exchangeSupportChatPickFilesFailed => '选择文件失败，请重试。';

  @override
  String get exchangeSupportChatSendMessageError => '无法发送您的消息。请重试。';

  @override
  String get exchangeSupportChatSendTooltip => 'Send message';

  @override
  String get exchangeSupportChatTitle => '支持地图';

  @override
  String get exchangeSupportChatYesterday => '昨天';

  @override
  String get exchangeSupportLoginChatRequired =>
      '如需人工支持，您必须先登录您的 Bull Bitcoin 账户。完全免费，无需 KYC，只需一个电子邮件地址。';

  @override
  String get oopsSomethingWentWrong => 'Oops! 某些错误';

  @override
  String get exchangeSupportChatLogDraft => 'Here are my logs';
}
