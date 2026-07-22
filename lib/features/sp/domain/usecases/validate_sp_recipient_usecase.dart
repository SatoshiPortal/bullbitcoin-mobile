import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_address_kind.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_recipient.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_network_usecase.dart';

/// Classifies a recipient address and builds the [SpRecipient] for the send
/// flow. Rejects a silent payment address whose network prefix doesn't match
/// the wallet network (an up-front UX check; full checksum/format validation is
/// deferred to Rust at prepare). Fails closed on a network read error rather
/// than skipping the wrong-network guard.
class ValidateSpRecipientUsecase {
  final GetSpNetworkUsecase _getSpNetworkUsecase;

  ValidateSpRecipientUsecase({required this._getSpNetworkUsecase});

  Result<SpRecipient, SpFailure> execute({
    required String input,
    required BigInt amountSat,
    required bool isMax,
  }) {
    final trimmed = input.trim();
    final kind = classifySpAddress(trimmed);
    if (kind == SpAddressKind.unrecognized) {
      return const Err(SpUnexpected('Unsupported SP recipient'));
    }
    final isSp = kind.isSilentPayment;

    if (isSp) {
      final SpNetwork? network;
      try {
        network = _getSpNetworkUsecase.execute();
      } catch (e) {
        return Err(SpUnexpected('SP network read failed: $e'));
      }
      if (network != null && !_allowedNetworks(kind).contains(network)) {
        return const Err(SpAddressNetworkMismatch());
      }
    }

    final recipient = isSp
        ? SpRecipientSp(address: trimmed, amountSat: amountSat, isMax: isMax)
        : SpRecipientStandard(
            address: trimmed,
            amountSat: amountSat,
            isMax: isMax,
          );
    return Ok(recipient);
  }

  // Networks a silent payment address of the given kind may be sent to. The
  // tsp1 hrp is shared by testnet and signet, so both are accepted for it.
  Set<SpNetwork> _allowedNetworks(SpAddressKind kind) => switch (kind) {
    SpAddressKind.silentPaymentMainnet => const {SpNetwork.bitcoin},
    SpAddressKind.silentPaymentRegtest => const {SpNetwork.regtest},
    SpAddressKind.silentPaymentTestnet => const {
      SpNetwork.testnet,
      SpNetwork.signet,
    },
    SpAddressKind.bitcoin || SpAddressKind.unrecognized => const {},
  };
}
