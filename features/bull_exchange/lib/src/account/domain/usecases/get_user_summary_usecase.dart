import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';

/// Reads the summary of the session's account.
class GetUserSummaryUsecase {
  final Exchange _exchange;

  const GetUserSummaryUsecase(this._exchange);

  Future<ExchangeRead<UserSummary>> execute(ExchangeSession session) async =>
      readOfResult(await _exchange.getUserSummary(session.environment));
}
