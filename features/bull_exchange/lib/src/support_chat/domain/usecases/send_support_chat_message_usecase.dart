import '../exchange_support_chat_failure.dart';

import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class SendSupportChatMessageUsecase {
  final Exchange _exchange;

  const SendSupportChatMessageUsecase({required this._exchange});

  /// Sends [text] with [attachments]; a message without attachments is sent
  /// without the attachments field.
  @useResult
  Future<Result<void, ExchangeSupportChatFailure>> execute(
    ExchangeSession? session, {
    required String text,
    List<SupportChatMessageAttachment> attachments = const [],
  }) async =>
      (switch (session) {
        null => const Err<void, ExchangeFailure>(
          ExchangeNotAuthenticatedFailure(),
        ),
        final session => await _exchange.sendSupportMessage(
          session,
          text: text,
          attachments: attachments.isEmpty ? null : attachments,
        ),
      }).mapErr(
        (failure) => switch (failure) {
          ExchangeNotAuthenticatedFailure() => const NotAuthenticatedFailure(),
          ExchangeChatSendMessageFailure() => SendMessageFailure(
            failure.logMessage,
          ),
          _ => const ExchangeSupportChatUnexpectedFailure(),
        },
      );
}
