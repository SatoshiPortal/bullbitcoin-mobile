import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class GetSupportChatMessageAttachmentUsecase {
  final Exchange _exchange;

  const GetSupportChatMessageAttachmentUsecase({required this._exchange});

  @useResult
  Future<Result<SupportChatMessageAttachment, ExchangeFailure>> execute(
    ExchangeSession? session,
    String attachmentId,
  ) async =>
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
          ExchangeNotAuthenticatedFailure() =>
            const ExchangeChatNotAuthenticatedFailure(),
          ExchangeChatLoadAttachmentFailure() => failure,
          _ => const ExchangeUnexpectedFailure(),
        },
      );
}
