import 'package:exchange/exchange.dart';
import 'package:exchange/funding.dart';
import 'package:primitives/primitives.dart';

/// The banks the COP bank transfer can be paid from: the institutions of
/// that rail's jurisdiction. An empty list is an answer.
class GetCopFundingInstitutionsUsecase {
  final Exchange _exchange;

  const GetCopFundingInstitutionsUsecase(this._exchange);

  Future<Result<List<FundingInstitution>, ExchangeReadFailure>> execute(
    ExchangeSession session,
  ) => _exchange.funding.institutions(
    session,
    const CopBankTransferFundingRail().jurisdiction,
  );
}
