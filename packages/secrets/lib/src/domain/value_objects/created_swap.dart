import 'package:meta/meta.dart';

/// The NON-secret result of creating a Boltz swap. The raw swap object (with its
/// per-swap `KeyPair` secret) never leaves `secrets`; this carries only the
/// public facts the app needs to proceed and to persist for a later claim/refund
/// (built app-side from the per-swap keypair it re-derives at the same index):
/// the swap id, the (untrusted-but-commitment-checked) lockup address, the
/// amount, our own public key(s), the preimage's sha256, and the Boltz-chosen
/// lockup locktime (surfaced, not gated — the caller cannot know it pre-call).
@immutable
class CreatedSwap {
  const CreatedSwap({
    required this.id,
    required this.scriptAddress,
    required this.outAmountSat,
    required this.preimageSha256,
    this.invoice,
    this.ownClaimPubkey,
    this.ownRefundPubkey,
    this.lockupLocktime,
  });

  final String id;
  final String scriptAddress;
  final int outAmountSat;

  /// sha256 of the swap's generated preimage — the payment hash. NON-secret
  /// (the preimage itself never leaves the package).
  final String preimageSha256;

  final String? invoice;

  /// Our own derived public key(s) for the side(s) we control (claim for
  /// reverse, refund for submarine, BOTH for chain). Public — safe to surface.
  final String? ownClaimPubkey;
  final String? ownRefundPubkey;

  /// The redeem-script CLTV locktime of the lockup (refund) leg, surfaced so the
  /// app can inspect/telemeter the refund window Boltz chose.
  final int? lockupLocktime;

  @override
  bool operator ==(Object other) =>
      other is CreatedSwap &&
      other.id == id &&
      other.scriptAddress == scriptAddress &&
      other.outAmountSat == outAmountSat &&
      other.preimageSha256 == preimageSha256 &&
      other.invoice == invoice &&
      other.ownClaimPubkey == ownClaimPubkey &&
      other.ownRefundPubkey == ownRefundPubkey &&
      other.lockupLocktime == lockupLocktime;

  @override
  int get hashCode => Object.hash(id, scriptAddress, outAmountSat,
      preimageSha256, invoice, ownClaimPubkey, ownRefundPubkey, lockupLocktime);

  @override
  String toString() => 'CreatedSwap($id, $scriptAddress, $outAmountSat sat)';
}
