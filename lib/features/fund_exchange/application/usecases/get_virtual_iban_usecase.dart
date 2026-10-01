import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/fund_exchange/application/fund_exchange_application_error.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';

class GetVirtualIbanUsecase {
  final RecipientsFacade _recipientsFacade;

  GetVirtualIbanUsecase({required this._recipientsFacade});

  Future<VirtualIban> execute() async {
    final result = await _recipientsFacade
        .watchVirtualIbanActivation(createIfAbsent: false)
        .first;
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure.toFundExchangeError(),
    };
  }
}

extension VirtualIbanFailureToFundExchangeError on RecipientsFailure {
  FundExchangeApplicationError toFundExchangeError() => switch (this) {
    VirtualIbanNotAvailableFailure(:final logMessage) =>
      FetchFundingDetailsFailed(
        code: 'ERR_RCP_PO404',
        message: logMessage ?? '',
      ),
    VirtualIbanEuResidencyRequiredFailure(:final logMessage) =>
      FetchFundingDetailsFailed(code: 'ERR_RCP_400', message: logMessage ?? ''),
    _ => FetchFundingDetailsFailed(message: logMessage ?? ''),
  };
}
