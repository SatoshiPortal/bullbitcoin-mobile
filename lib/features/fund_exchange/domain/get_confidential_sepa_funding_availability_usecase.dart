import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:meta/meta.dart';

/// Whether to offer Confidential SEPA as a funding method. The user can be
/// offered it before their virtual IBAN exists: the funding flow creates it.
class GetConfidentialSepaFundingAvailabilityUsecase {
  final RecipientsFacade _recipientsFacade;

  const GetConfidentialSepaFundingAvailabilityUsecase(this._recipientsFacade);

  @useResult
  Future<Result<bool, FundExchangeFailure>> execute() async {
    return switch (await _recipientsFacade.getConfidentialSepaAvailability()) {
      Ok(:final value) => Ok(value != ConfidentialSepaAvailability.unavailable),
      Err(failure: RecipientsNetworkFailure()) => const Err(
        FundExchangeNetworkFailure(),
      ),
      Err(:final failure) => Err(
        FundExchangeUnexpectedFailure(failure.runtimeType.toString()),
      ),
    };
  }
}
