import 'package:meta/meta.dart';

/// Direction of a chain swap (which chain is the source). Package-pure mirror of
/// the SDK's enum so no native type crosses the `secrets` boundary.
enum ChainDirection { btcToLbtc, lbtcToBtc }

/// A transaction output the user intends to create.
@immutable
class Output {
  const Output({required this.scriptPubKey, required this.amountSat});

  /// The output's scriptPubKey as LOWERCASE HEX of the raw script bytes — NOT a
  /// bech32/base58 address. The validator matches it byte-for-byte against the
  /// tx's extracted output scripts, so a caller passing an address gets a
  /// confusing "declared output is missing" rejection (fail-closed). Convert the
  /// recipient address to its scriptPubKey hex before constructing an [Output].
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

/// What the user intends a signature to authorize. A [SignerPort] MUST validate
/// the intent against the PSBT/PSET BEFORE signing — BDK/LWK sign blindly (issue
/// #1703), so this is the security gate that closes the `trustWitnessUtxo`
/// fee-inflation footgun. (Swap CREATION is a separate surface: see
/// `SwapRequest` + `IntentValidator.validateSwapCommitment`.)
@immutable
sealed class SigningIntent {
  const SigningIntent();
}

/// A plain send. Every input and every non-recipient (change) output must be
/// provably owned by the SIGNING wallet — ownership is decided by the signer
/// from the seed-derived descriptor (`wallet.isMine`), not carried in the
/// intent — and the fee is capped ([maxFeeSat]).
final class SendIntent extends SigningIntent {
  const SendIntent({
    required this.outputs,
    required this.maxFeeSat,
  });

  /// The recipient outputs the user authorized. Any extra tx output must be
  /// owned change; any of these missing from the tx is rejected.
  final List<Output> outputs;

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
