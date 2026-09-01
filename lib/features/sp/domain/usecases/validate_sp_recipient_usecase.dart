import 'package:bb_mobile/features/sp/domain/entities/sp_address.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_recipient.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_recipient_address_validator_port.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_network_usecase.dart';
import 'package:primitives/primitives.dart';

/// Builds the [SpRecipient] for the send flow from a BWK-validated address.
class ValidateSpRecipientUsecase {
  final GetSpNetworkUsecase getSpNetworkUsecase;
  final SpRecipientAddressValidatorPort validator;

  ValidateSpRecipientUsecase({
    required this.getSpNetworkUsecase,
    required this.validator,
  });

  Future<Result<SpRecipient, SpFailure>> execute({
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
        if (value == null) return const Err(SpNotSetUp());
        network = value;
    }
    switch (await validator.validateRecipientAddress(addressText, network)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final address = SpAddress(addressText);
        return Ok(
          value == SpRecipientAddressType.silentPayment
              ? SpRecipientSp(
                  address: address,
                  amountSat: amountSat,
                  isMax: isMax,
                )
              : SpRecipientStandard(
                  address: address,
                  amountSat: amountSat,
                  isMax: isMax,
                ),
        );
    }
  }
}
