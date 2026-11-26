import 'package:exchange/exchange.dart';
import 'package:exchange/funding.dart';

/// Reads the account facts the fund flow decides from.
class GetFundingAccountUsecase {
  final Exchange _exchange;

  const GetFundingAccountUsecase(this._exchange);

  Future<ExchangeRead<FundingAccount>> execute(ExchangeSession session) =>
      _exchange.funding.account(session);
}
