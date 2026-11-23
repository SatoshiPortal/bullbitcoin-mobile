import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../map_virtual_iban_failure.dart';

class GetConfidentialSepaAvailabilityUsecase {
  final Exchange _exchange;

  const GetConfidentialSepaAvailabilityUsecase(this._exchange);

  @useResult
  Future<Result<ConfidentialSepaAvailability, RecipientsFailure>>
  execute() async => (await _exchange.getConfidentialSepaAvailability()).mapErr(
    mapVirtualIbanFailure,
  );
}
