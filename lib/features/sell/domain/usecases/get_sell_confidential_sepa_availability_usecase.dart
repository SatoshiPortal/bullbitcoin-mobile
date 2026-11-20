import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class GetSellConfidentialSepaAvailabilityUsecase {
  final RecipientsFacade _recipients;

  const GetSellConfidentialSepaAvailabilityUsecase(this._recipients);

  @useResult
  Future<Result<ConfidentialSepaAvailability, SellFailure>> execute(
    FiatCurrency currency,
  ) async {
    if (currency != FiatCurrency.eur) {
      return const Ok(ConfidentialSepaAvailability.unavailable);
    }
    return switch (await _recipients.getConfidentialSepaAvailability()) {
      Ok(:final value) => Ok(value),
      Err(failure: RecipientsNetworkFailure()) => const Err(
        SellNetworkFailure(),
      ),
      Err() => const Err(SellUnexpectedFailure()),
    };
  }
}
