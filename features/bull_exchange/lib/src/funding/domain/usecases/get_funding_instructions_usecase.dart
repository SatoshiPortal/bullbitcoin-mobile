import 'package:exchange/exchange.dart';
import 'package:exchange/funding.dart';
import 'package:primitives/primitives.dart';

/// A rail's funding instructions for [FundingRequest], or the exchange's
/// refusal.
class GetFundingInstructionsUsecase {
  final Exchange _exchange;

  const GetFundingInstructionsUsecase(this._exchange);

  Future<Result<FundingAnswer, ExchangeReadFailure>> execute(
    ExchangeSession session,
    FundingRequest request,
  ) => _exchange.funding.instructions(session, request);
}
