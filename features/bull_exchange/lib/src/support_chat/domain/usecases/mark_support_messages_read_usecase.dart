import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Marks every support message of the session's user as read; never sent
/// for a session that is no longer the current one.
class MarkSupportMessagesReadUsecase {
  final Exchange _exchange;

  const MarkSupportMessagesReadUsecase(this._exchange);

  Future<Result<void, ExchangeWriteFailure>> execute(ExchangeSession session) =>
      _exchange.markSupportMessagesRead(session);
}
