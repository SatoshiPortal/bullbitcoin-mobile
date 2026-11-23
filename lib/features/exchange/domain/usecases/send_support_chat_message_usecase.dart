import 'package:bb_mobile/core/exchange/domain/exchange_support_chat_failure.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class SendSupportChatMessageUsecase {
  final Exchange _exchange;

  const SendSupportChatMessageUsecase({required this._exchange});

  @useResult
  Future<Result<void, ExchangeSupportChatFailure>> execute({
    required String text,
    List<SupportChatMessageAttachment>? attachments,
  }) async =>
      (await _exchange.sendSupportMessage(
        text: text,
        attachments: attachments,
      )).mapErr(
        (failure) => switch (failure) {
          ExchangeNotAuthenticatedFailure() => const NotAuthenticatedFailure(),
          ExchangeChatSendMessageFailure() => SendMessageFailure(
            failure.logMessage,
          ),
          _ => const ExchangeSupportChatUnexpectedFailure(),
        },
      );
}
