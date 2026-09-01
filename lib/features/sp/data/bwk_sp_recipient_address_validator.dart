import 'package:bb_mobile/features/sp/data/mappers/sp_network_mapper.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_recipient_address_validator_port.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bull_sdk/bwk.dart' as bwk;
import 'package:primitives/primitives.dart';

class BwkSpRecipientAddressValidator
    implements SpRecipientAddressValidatorPort {
  final Future<bwk.SpRecipientAddressKind> Function({
    required String address,
    required bwk.SpNetwork network,
  })
  _validateRecipientAddress;

  BwkSpRecipientAddressValidator({
    Future<bwk.SpRecipientAddressKind> Function({
      required String address,
      required bwk.SpNetwork network,
    })?
    validateRecipientAddress,
  }) : _validateRecipientAddress =
           validateRecipientAddress ?? bwk.validateRecipientAddress;

  @override
  Future<Result<SpRecipientAddressType, SpFailure>> validateRecipientAddress(
    String address,
    BitcoinNetwork network,
  ) async {
    try {
      final kind = await _validateRecipientAddress(
        address: address,
        network: SpNetworkMapper.toFfi(network),
      );
      return Ok(switch (kind) {
        bwk.SpRecipientAddressKind.sp => SpRecipientAddressType.silentPayment,
        bwk.SpRecipientAddressKind.standard => SpRecipientAddressType.standard,
      });
    } catch (e) {
      final message = e.toString();
      if (message.contains('wrong network')) {
        return Err(SpAddressNetworkMismatch(message));
      }
      return Err(SpInvalidAddress(message));
    }
  }
}
