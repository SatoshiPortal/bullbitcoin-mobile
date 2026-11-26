import 'package:bull_exchange/src/support_chat/domain/exchange_support_chat_failure.dart';
import 'package:bull_exchange/src/support_chat/domain/usecases/create_log_attachment_usecase.dart';
import 'package:bull_exchange/src/support_chat/domain/usecases/get_support_chat_messages_usecase.dart';
import 'package:bull_exchange/src/support_chat/domain/usecases/open_support_chat_attachment_usecase.dart';
import 'package:bull_exchange/src/support_chat/domain/usecases/pick_image_attachments_usecase.dart';
import 'package:bull_exchange/src/support_chat/domain/usecases/send_support_chat_message_usecase.dart';
import 'package:bull_exchange/src/support_chat/domain/usecases/watch_support_chat_pushes_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

typedef ChatResult<T> = Future<Result<T, ExchangeSupportChatFailure>>;

final class FakeGetSupportChatMessagesUsecase
    implements GetSupportChatMessagesUsecase {
  final ChatResult<List<SupportChatMessage>> Function({
    int? page,
    int? pageSize,
  })
  answer;

  FakeGetSupportChatMessagesUsecase(this.answer);

  @override
  ChatResult<List<SupportChatMessage>> execute({int? page, int? pageSize}) =>
      answer(page: page, pageSize: pageSize);
}

final class FakeSendSupportChatMessageUsecase
    implements SendSupportChatMessageUsecase {
  final ChatResult<void> Function({
    required String text,
    List<SupportChatMessageAttachment> attachments,
  })
  answer;

  FakeSendSupportChatMessageUsecase(this.answer);

  @override
  ChatResult<void> execute({
    required String text,
    List<SupportChatMessageAttachment> attachments = const [],
  }) => answer(text: text, attachments: attachments);
}

final class FakePickImageAttachmentsUsecase
    implements PickImageAttachmentsUsecase {
  final ChatResult<List<SupportChatMessageAttachment>> Function() answer;

  FakePickImageAttachmentsUsecase(this.answer);

  @override
  ChatResult<List<SupportChatMessageAttachment>> execute() => answer();
}

final class FakeCreateLogAttachmentUsecase
    implements CreateLogAttachmentUsecase {
  final ChatResult<SupportChatMessageAttachment> Function() answer;

  FakeCreateLogAttachmentUsecase(this.answer);

  @override
  ChatResult<SupportChatMessageAttachment> execute() => answer();
}

final class FakeOpenSupportChatAttachmentUsecase
    implements OpenSupportChatAttachmentUsecase {
  final ChatResult<void> Function(String attachmentId) answer;

  FakeOpenSupportChatAttachmentUsecase(this.answer);

  @override
  Never get getAttachment =>
      throw StateError('the fake open use case has no attachment read');

  @override
  ChatResult<void> execute(String attachmentId) => answer(attachmentId);
}

final class FakeWatchSupportChatPushesUsecase
    implements WatchSupportChatPushesUsecase {
  final Stream<NotificationMessage> Function() answer;

  FakeWatchSupportChatPushesUsecase(this.answer);

  @override
  Stream<NotificationMessage> execute() => answer();
}
