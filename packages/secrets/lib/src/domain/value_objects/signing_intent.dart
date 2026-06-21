import 'package:meta/meta.dart';

import 'descriptors.dart';

/// Direction of a Boltz swap. Submarine = on-chain → Lightning (uses the refund
/// key); reverse = Lightning → on-chain (uses the claim key); chain commits to
/// BOTH.
enum SwapDirection { submarine, reverse, chain }

/// Direction of a chain swap (which chain is the source). Package-pure mirror of
/// the SDK's enum so no native type crosses the `secrets` boundary.
enum ChainDirection { btcToLbtc, lbtcToBtc }

/// A transaction output the user intends to create.
@immutable
class Output {
  const Output({required this.scriptPubKey, required this.amountSat});
  final String scriptPubKey;
  final int amountSat;

  @override
  bool operator ==(Object other) =>
      other is Output &&
      other.scriptPubKey == scriptPubKey &&
      other.amountSat == amountSat;

  @override
  int get hashCode => Object.hash(scriptPubKey, amountSat);

  @override
  String toString() => 'Output($scriptPubKey, $amountSat sat)';
}

/// What the user intends a signature to authorize. A [SignerPort]/[SwapSignerPort]
/// MUST validate the intent against the PSBT/PSET/redeem-script BEFORE signing —
/// BDK/LWK sign blindly (issue #1703), so this is the security gate that closes
/// the `trustWitnessUtxo` fee-inflation footgun and untrusted-address attacks.
@immutable
sealed class SigningIntent {
  const SigningIntent();
}

/// A plain send. Change must be provably owned ([walletDescriptor]) and the fee
/// capped ([maxFeeSat]).
final class SendIntent extends SigningIntent {
  const SendIntent({
    required this.outputs,
    required this.walletDescriptor,
    required this.maxFeeSat,
  });

  /// Assert every change output is owned by [walletDescriptor].
  final List<Output> outputs;
  final BitcoinDescriptor walletDescriptor;

  /// Reject if the implied fee exceeds this.
  final int maxFeeSat;
}

/// A BIP78 payjoin contribution. The sender checklist requires asserting the
/// original inputs/outputs/version/locktime are unchanged and the extra fee
/// contribution is bounded.
final class PayjoinIntent extends SigningIntent {
  const PayjoinIntent({
    required this.originalInputs,
    required this.originalOutputs,
    required this.originalVersion,
    required this.originalLockTime,
    required this.maxFeeContributionSat,
  });

  final List<String> originalInputs;
  final List<Output> originalOutputs;
  final int originalVersion;
  final int originalLockTime;
  final int maxFeeContributionSat;
}

/// A Boltz swap. Carries the redeem-script components so the swap signer can
/// reconstruct the script from its OWN derived key and assert the lockup output
/// commits to it (the Boltz-supplied address is untrusted). A chain swap
/// commits to BOTH [claimPubkey] and [refundPubkey]; submarine uses refund,
/// reverse uses claim.
final class SwapIntent extends SigningIntent {
  const SwapIntent({
    required this.preimageHash,
    required this.claimPubkey,
    required this.refundPubkey,
    required this.timeout,
    required this.amountSat,
    required this.direction,
  });

  final String preimageHash;
  final String claimPubkey;
  final String refundPubkey;
  final int timeout;
  final int amountSat;
  final SwapDirection direction;
}
