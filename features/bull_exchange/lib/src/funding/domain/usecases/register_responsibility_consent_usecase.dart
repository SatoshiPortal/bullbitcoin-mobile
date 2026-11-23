import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/funding/domain/fund_exchange_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../map_funding_failure.dart';

class RegisterResponsibilityConsentCommand {
  const RegisterResponsibilityConsentCommand();
}

class RegisterResponsibilityConsentResult {
  const RegisterResponsibilityConsentResult();
}

class RegisterResponsibilityConsentUsecase {
  final ExchangeFunding _funding;

  const RegisterResponsibilityConsentUsecase({required this._funding});

  @useResult
  Future<Result<RegisterResponsibilityConsentResult, FundExchangeFailure>>
  execute(RegisterResponsibilityConsentCommand command) async {
    final result = (await _funding.registerResponsibilityConsent()).mapErr(
      mapFundingFailure,
    );

    return result.map((_) => const RegisterResponsibilityConsentResult());
  }
}
