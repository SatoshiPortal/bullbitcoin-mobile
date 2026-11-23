import 'package:bb_mobile/core/exchange/domain/exchange_support_chat_failure.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class GetSupportChatMessageAttachmentUsecase {
  final Exchange _exchange;

  const GetSupportChatMessageAttachmentUsecase({required this._exchange});

  @useResult
  Future<Result<SupportChatMessageAttachment, ExchangeSupportChatFailure>>
  execute(String attachmentId) async =>
      (await _exchange.getSupportAttachment(attachmentId)).mapErr(
        (failure) => switch (failure) {
          ExchangeNotAuthenticatedFailure() => const NotAuthenticatedFailure(),
          ExchangeChatLoadAttachmentFailure() => LoadAttachmentFailure(
            failure.logMessage,
          ),
          _ => const ExchangeSupportChatUnexpectedFailure(),
        },
      );
}
