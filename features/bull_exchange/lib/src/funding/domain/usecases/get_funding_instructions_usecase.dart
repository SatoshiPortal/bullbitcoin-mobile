import 'package:exchange/exchange.dart';
import 'package:exchange/funding.dart';

/// A rail's funding instructions for [FundingRequest], or the exchange's
/// refusal.
class GetFundingInstructionsUsecase {
  final Exchange _exchange;

  const GetFundingInstructionsUsecase(this._exchange);

  Future<ExchangeRead<FundingAnswer>> execute(
    ExchangeSession session,
    FundingRequest request,
  ) => _exchange.funding.instructions(session, request);
}
