import 'package:silent/src/domain/entities/sp_address.dart';
import 'package:silent/src/domain/entities/sp_recipient.dart';
import 'package:silent/src/domain/ports/sp_recipient_address_validator_port.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/domain/usecases/get_sp_network_usecase.dart';
import 'package:primitives/primitives.dart';

/// Builds the [SilentRecipient] for the send flow from a BWK-validated address.
class ValidateSpRecipientUsecase {
  final GetSpNetworkUsecase getSpNetworkUsecase;
  final SpRecipientAddressValidatorPort validator;

  ValidateSpRecipientUsecase({
    required this.getSpNetworkUsecase,
    required this.validator,
  });

  Future<Result<SilentRecipient, SilentFailure>> execute({
    required String input,
    required Sats amountSat,
    required bool isMax,
  }) async {
    final addressText = input.trim();
    final BitcoinNetwork network;
    switch (getSpNetworkUsecase.execute()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (value == null) return const Err(SilentNotSetUp());
        network = value;
    }
    switch (await validator.validateRecipientAddress(addressText, network)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final address = SilentAddress(addressText);
        return Ok(
          value == SpRecipientAddressType.silentPayment
              ? SilentRecipientSp(
                  address: address,
                  amountSat: amountSat,
                  isMax: isMax,
                )
              : SilentRecipientStandard(
                  address: address,
                  amountSat: amountSat,
                  isMax: isMax,
                ),
        );
    }
  }
}
