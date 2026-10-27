import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class GetSellConfidentialSepaAvailabilityUsecaseV2 {
  final RecipientsFacade _recipients;

  const GetSellConfidentialSepaAvailabilityUsecaseV2(this._recipients);

  @useResult
  Future<Result<ConfidentialSepaAvailability, SellFailure>> execute() async =>
      switch (await _recipients.getConfidentialSepaAvailability()) {
        Ok(:final value) => Ok(value),
        Err(failure: RecipientsNetworkFailure()) => const Err(
          SellNetworkFailure(),
        ),
        Err() => const Err(SellUnexpectedFailure()),
      };
}
