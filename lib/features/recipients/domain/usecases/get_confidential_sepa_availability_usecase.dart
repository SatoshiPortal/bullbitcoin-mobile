import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/get_recipients_environment_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/entities/virtual_iban.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/virtual_iban_repository.dart';
import 'package:bb_mobile/features/recipients/domain/entities/confidential_sepa_availability.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// Confidential SEPA is for fully verified individual accounts in the
/// European Union, and needs an active virtual IBAN.
class GetConfidentialSepaAvailabilityUsecase {
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final VirtualIbanRepository _virtualIbanRepository;
  final GetRecipientsEnvironmentUsecase _getRecipientsEnvironmentUsecase;

  const GetConfidentialSepaAvailabilityUsecase({
    required this._getExchangeUserSummaryUsecase,
    required this._virtualIbanRepository,
    required this._getRecipientsEnvironmentUsecase,
  });

  @useResult
  Future<Result<ConfidentialSepaAvailability, RecipientsFailure>>
  execute() async {
    final bool isEligible;
    try {
      final summary = await _getExchangeUserSummaryUsecase.execute();
      isEligible =
          summary.isFullyVerifiedKycLevel &&
          !summary.isCorporate &&
          summary.isEuropeanJurisdiction;
    } on Object catch (e, st) {
      log.warning(
        'Could not read the exchange summary for Confidential SEPA',
        error: e,
        trace: st,
      );
      return const Err(RecipientsUnexpectedFailure());
    }
    if (!isEligible) return const Ok(ConfidentialSepaAvailability.unavailable);

    final bool isTestnet;
    switch (await _getRecipientsEnvironmentUsecase.execute()) {
      case Ok(:final value):
        isTestnet = value.isTestnet;
      case Err(:final failure):
        return Err(failure);
    }

    return (await _virtualIbanRepository.find(isTestnet: isTestnet)).map(
      (virtualIban) => virtualIban is ActiveVirtualIban
          ? ConfidentialSepaAvailability.ready
          : ConfidentialSepaAvailability.needsVirtualIban,
    );
  }
}
