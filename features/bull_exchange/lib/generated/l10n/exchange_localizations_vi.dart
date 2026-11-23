// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'exchange_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class ExchangeLocalizationsVi extends ExchangeLocalizations {
  ExchangeLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get exchangeSupportChatAttachFileTooltip => 'Attach a file';

  @override
  String get exchangeSupportChatAttachLogsFailed =>
      'Không thể đính kèm nhật ký. Vui lòng thử lại.';

  @override
  String get exchangeSupportChatAttachLogsTooltip => 'Attach logs';

  @override
  String get exchangeSupportChatAttachmentImage => 'Hình ảnh';

  @override
  String get exchangeSupportChatAttachmentUnknownFile => 'Tệp không xác định';

  @override
  String get exchangeSupportChatEmptyState =>
      'Chưa có tin nhắn nào. Hãy bắt đầu trò chuyện!';

  @override
  String get exchangeSupportChatFetchFileDataFailed =>
      'Không thể lấy dữ liệu tệp';

  @override
  String get exchangeSupportChatInputHint => 'Nhập tin nhắn...';

  @override
  String get exchangeSupportChatLoadAttachmentError =>
      'Không thể mở tệp đính kèm. Vui lòng thử lại.';

  @override
  String get exchangeSupportChatLoadMessagesError =>
      'Không thể tải tin nhắn. Vui lòng thử lại.';

  @override
  String get exchangeSupportChatMessageEmptyError =>
      'Tin nhắn không được để trống';

  @override
  String get exchangeSupportChatMessageRequired => 'Cần có tin nhắn';

  @override
  String get exchangeSupportChatPickFilesFailed =>
      'Không thể chọn tệp. Vui lòng thử lại.';

  @override
  String get exchangeSupportChatSendMessageError =>
      'Không thể gửi tin nhắn của bạn. Vui lòng thử lại.';

  @override
  String get exchangeSupportChatSendTooltip => 'Send message';

  @override
  String get exchangeSupportChatTitle => 'Trò chuyện hỗ trợ';

  @override
  String get exchangeSupportChatYesterday => 'Hôm qua';

  @override
  String get exchangeSupportLoginChatRequired =>
      'Để nhận hỗ trợ từ nhân viên, bạn cần đăng nhập vào tài khoản Bull Bitcoin của mình trước. Hoàn toàn miễn phí và không yêu cầu KYC, chỉ cần một địa chỉ email.';

  @override
  String get oopsSomethingWentWrong => 'Rất tiếc! Đã xảy ra lỗi';

  @override
  String get exchangeSupportChatLogDraft => 'Here are my logs';
}
