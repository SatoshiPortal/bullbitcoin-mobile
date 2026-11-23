import 'package:primitives/primitives.dart';
import 'package:bull_exchange/src/funding/domain/fund_exchange_failure.dart';
import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';

import '../map_funding_failure.dart';

/// Whether to offer Confidential SEPA as a funding method. The user can be
/// offered it before their virtual IBAN exists: the funding flow creates it.
class GetConfidentialSepaFundingAvailabilityUsecase {
  final Exchange _exchange;

  const GetConfidentialSepaFundingAvailabilityUsecase(this._exchange);

  @useResult
  Future<Result<bool, FundExchangeFailure>> execute() async =>
      (await _exchange.getConfidentialSepaAvailability())
          .map((value) => value != ConfidentialSepaAvailability.unavailable)
          .mapErr(mapFundingFailure);
}
