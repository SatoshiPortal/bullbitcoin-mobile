import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class GetSupportChatMessagesUsecase {
  final Exchange _exchange;

  const GetSupportChatMessagesUsecase({required this._exchange});

  @useResult
  Future<Result<List<SupportChatMessage>, ExchangeFailure>> execute(
    ExchangeSession? session, {
    int? page,
    int? pageSize,
  }) async =>
      (switch (session) {
        null => const Err<List<SupportChatMessage>, ExchangeFailure>(
          ExchangeNotAuthenticatedFailure(),
        ),
        final ExchangeSession session => await _exchange.getSupportMessages(
          session,
          page: page,
          pageSize: pageSize,
        ),
      }).mapErr(
        (failure) => switch (failure) {
          ExchangeNotAuthenticatedFailure() =>
            const ExchangeChatNotAuthenticatedFailure(),
          ExchangeChatLoadMessagesFailure() => failure,
          _ => const ExchangeUnexpectedFailure(),
        },
      );
}
