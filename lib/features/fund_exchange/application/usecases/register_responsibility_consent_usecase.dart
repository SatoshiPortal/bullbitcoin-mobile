import 'package:bb_mobile/features/fund_exchange/application/ports/funding_gateway_port.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class RegisterResponsibilityConsentCommand {
  const RegisterResponsibilityConsentCommand();
}

class RegisterResponsibilityConsentResult {
  const RegisterResponsibilityConsentResult();
}

class RegisterResponsibilityConsentUsecase {
  final FundingGatewayPort _fundingGateway;

  const RegisterResponsibilityConsentUsecase({required this._fundingGateway});

  @useResult
  Future<Result<RegisterResponsibilityConsentResult, FundExchangeFailure>>
  execute(RegisterResponsibilityConsentCommand command) async {
    final result = await _fundingGateway.registerResponsibilityConsent();

    return result.map((_) => const RegisterResponsibilityConsentResult());
  }
}
