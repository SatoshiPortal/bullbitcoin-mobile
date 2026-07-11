import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_recipient.dart';

/// A confirmed transaction draft (coin selection + fee preview) shown on the
/// send confirm page and pinned into finalize.
///
/// [handle] is the opaque bwk `TxSimulation`, held as `Object` so the domain
/// stays FFI-free. It MUST round-trip UNCHANGED into
/// `finalizeSignBroadcast`: the Rust side pins the tx to this exact confirmed
/// simulation and rejects a drifted coin set, so it is never reconstructed.
/// The typed fields below are read-only display data mapped off the same
/// simulation.
class SpTxDraft {
  final Object handle;
  final List<SpCoin> inputs;
  final List<SpRecipient> outputs;
  final BigInt feeSat;
  final BigInt changeSat;

  const SpTxDraft({
    required this.handle,
    required this.inputs,
    required this.outputs,
    required this.feeSat,
    required this.changeSat,
  });
}
