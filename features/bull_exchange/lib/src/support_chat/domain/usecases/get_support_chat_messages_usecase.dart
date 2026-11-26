import '../exchange_support_chat_failure.dart';

import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class GetSupportChatMessagesUsecase {
  final Exchange _exchange;

  const GetSupportChatMessagesUsecase({required this._exchange});

  @useResult
  Future<Result<List<SupportChatMessage>, ExchangeSupportChatFailure>> execute({
    int? page,
    int? pageSize,
  }) async =>
      (await _exchange.getSupportMessages(
        page: page,
        pageSize: pageSize,
      )).mapErr(
        (failure) => switch (failure) {
          ExchangeNotAuthenticatedFailure() => const NotAuthenticatedFailure(),
          ExchangeChatLoadMessagesFailure() => LoadMessagesFailure(
            failure.logMessage,
          ),
          _ => const ExchangeSupportChatUnexpectedFailure(),
        },
      );
}
