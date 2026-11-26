import 'package:exchange/exchange.dart';

/// How many support messages the session's user has not read. A read for a
/// session that is no longer the current one is never sent.
class GetUnreadSupportCountUsecase {
  final Exchange _exchange;

  const GetUnreadSupportCountUsecase(this._exchange);

  Future<ExchangeRead<int>> execute(ExchangeSession session) =>
      _exchange.readUnreadSupportCount(session);
}
