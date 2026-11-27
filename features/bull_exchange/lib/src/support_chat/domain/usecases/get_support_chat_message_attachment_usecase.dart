import '../exchange_support_chat_failure.dart';

import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class GetSupportChatMessageAttachmentUsecase {
  final Exchange _exchange;

  const GetSupportChatMessageAttachmentUsecase({required this._exchange});

  @useResult
  Future<Result<SupportChatMessageAttachment, ExchangeSupportChatFailure>>
  execute(ExchangeSession? session, String attachmentId) async =>
      (switch (session) {
        null => const Err<SupportChatMessageAttachment, ExchangeFailure>(
          ExchangeNotAuthenticatedFailure(),
        ),
        final session => await _exchange.getSupportAttachment(
          session,
          attachmentId,
        ),
      }).mapErr(
        (failure) => switch (failure) {
          ExchangeNotAuthenticatedFailure() => const NotAuthenticatedFailure(),
          ExchangeChatLoadAttachmentFailure() => LoadAttachmentFailure(
            failure.logMessage,
          ),
          _ => const ExchangeSupportChatUnexpectedFailure(),
        },
      );
}
