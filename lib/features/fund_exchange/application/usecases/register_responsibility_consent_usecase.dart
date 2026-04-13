import 'package:bb_mobile/features/fund_exchange/application/fund_exchange_application_error.dart';
import 'package:bb_mobile/features/fund_exchange/application/ports/funding_gateway_port.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_domain_error.dart';

class RegisterResponsibilityConsentCommand {
  const RegisterResponsibilityConsentCommand();
}

class RegisterResponsibilityConsentResult {
  const RegisterResponsibilityConsentResult();
}

class RegisterResponsibilityConsentUsecase {
  final FundingGatewayPort _fundingGateway;

  const RegisterResponsibilityConsentUsecase({
    required FundingGatewayPort fundingGateway,
  }) : _fundingGateway = fundingGateway;

  Future<RegisterResponsibilityConsentResult> execute(
    RegisterResponsibilityConsentCommand command,
  ) async {
    try {
      await _fundingGateway.registerResponsibilityConsent();

      return RegisterResponsibilityConsentResult();
    } on FundExchangeDomainError catch (e) {
      throw FundExchangeApplicationError.fromDomainError(e);
    } on FundExchangeApplicationError {
      rethrow;
    } catch (e) {
      throw FundExchangeUnknownError(message: '$e');
    }
  }
}
