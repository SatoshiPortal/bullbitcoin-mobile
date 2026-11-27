import 'package:exchange/exchange.dart';
import 'package:exchange/funding.dart';
import 'package:primitives/primitives.dart';

/// Reads the account facts the fund flow decides from.
class GetFundingAccountUsecase {
  final Exchange _exchange;

  const GetFundingAccountUsecase(this._exchange);

  Future<Result<FundingAccount, ExchangeReadFailure>> execute(
    ExchangeSession session,
  ) => _exchange.funding.account(session);
}
