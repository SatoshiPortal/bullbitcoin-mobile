import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/funding/domain/fund_exchange_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class GetFundExchangeUserSummaryUsecase {
  final Exchange _exchange;

  const GetFundExchangeUserSummaryUsecase({required this._exchange});

  @useResult
  Future<Result<UserSummary, FundExchangeFailure>> execute() async =>
      (await _exchange.getUserSummary()).mapErr(
        (failure) => FundExchangeUnexpectedFailure(
          'User summary unavailable: ${failure.runtimeType}',
        ),
      );
}
