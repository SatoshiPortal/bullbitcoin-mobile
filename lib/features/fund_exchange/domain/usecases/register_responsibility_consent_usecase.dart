import 'package:bb_mobile/features/fund_exchange/domain/repositories/funding_repository.dart';
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
  final FundingRepository _fundingRepository;

  const RegisterResponsibilityConsentUsecase({
    required this._fundingRepository,
  });

  @useResult
  Future<Result<RegisterResponsibilityConsentResult, FundExchangeFailure>>
  execute(RegisterResponsibilityConsentCommand command) async {
    final result = await _fundingRepository.registerResponsibilityConsent();

    return result.map((_) => const RegisterResponsibilityConsentResult());
  }
}
