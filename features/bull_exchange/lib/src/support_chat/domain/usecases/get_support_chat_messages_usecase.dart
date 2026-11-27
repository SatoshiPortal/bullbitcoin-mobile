import '../exchange_support_chat_failure.dart';

import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class GetSupportChatMessagesUsecase {
  final Exchange _exchange;

  const GetSupportChatMessagesUsecase({required this._exchange});

  @useResult
  Future<Result<List<SupportChatMessage>, ExchangeSupportChatFailure>> execute(
    ExchangeSession? session, {
    int? page,
    int? pageSize,
  }) async =>
      (switch (session) {
        null => const Err<List<SupportChatMessage>, ExchangeFailure>(
          ExchangeNotAuthenticatedFailure(),
        ),
        final session => await _exchange.getSupportMessages(
          session,
          page: page,
          pageSize: pageSize,
        ),
      }).mapErr(
        (failure) => switch (failure) {
          ExchangeNotAuthenticatedFailure() => const NotAuthenticatedFailure(),
          ExchangeChatLoadMessagesFailure() => LoadMessagesFailure(
            failure.logMessage,
          ),
          _ => const ExchangeSupportChatUnexpectedFailure(),
        },
      );
}
