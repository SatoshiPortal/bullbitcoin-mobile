import 'package:meta/meta.dart';
import 'package:secrets/src/domain/value_objects/signing_intent.dart' show ChainDirection;

export 'package:secrets/src/domain/value_objects/signing_intent.dart' show ChainDirection;

/// A CALLER-KNOWABLE Boltz swap-creation request.
///
/// Replaces the old `SwapIntent`, which required `claimPubkey`/`refundPubkey`/
/// `preimageHash`/`timeout` up front — values the Boltz SDK only generates
/// *during* creation, so no caller could construct a passing intent (every
/// creator failed closed). A `SwapRequest` carries only what the caller knows
/// before the call (amounts, invoice, direction). The adapter builds the
/// expected commitment from the SDK-returned swap (own pubkey(s), the generated
/// preimage's `sha256`, the Boltz-chosen locktime) and validates it — the caller
/// supplies NO secret/pubkey/preimage.
@immutable
sealed class SwapRequest {
  const SwapRequest({this.referralId});

  /// Optional Boltz referral id (revenue attribution) forwarded to creation.
  final String? referralId;
}

/// Lightning → on-chain (we CLAIM). We know the exact amount we want to receive;
/// the created swap's `outAmount` must equal it EXACTLY.
final class ReverseSwapRequest extends SwapRequest {
  const ReverseSwapRequest({
    required this.requestedReceiveSat,
    this.outAddress,
    this.description,
    super.referralId,
  });

  /// The exact on-chain amount to receive (the caller passed it to Boltz).
  final int requestedReceiveSat;
  final String? outAddress;
  final String? description;
}

/// On-chain → Lightning (we pay an invoice; we hold the REFUND key). The lockup
/// `outAmount` (invoice + Boltz fee) is unknown pre-call, so it is bounded by a
/// range: at least the invoice amount, at most a caller-set ceiling.
final class SubmarineSwapRequest extends SwapRequest {
  const SubmarineSwapRequest({
    required this.invoice,
    required this.invoiceAmountSat,
    required this.maxLockupSat,
    super.referralId,
  });

  final String invoice;

  /// The invoice's amount — the FLOOR the lockup must at least cover.
  final int invoiceAmountSat;

  /// The maximum lockup the caller will tolerate (invoice + max Boltz fee).
  final int maxLockupSat;
}

/// A chain swap (BTC↔L-BTC). We commit to BOTH keys. The send/lockup `outAmount`
/// is exact (`sendAmountSat`); the net receive (`claim_details.amount`) is not
/// exposed on the swap object, so `minReceiveSat` is a caller/UI floor the
/// package does not gate on (documented residual — see ADOPTION §B).
final class ChainSwapRequest extends SwapRequest {
  const ChainSwapRequest({
    required this.sendAmountSat,
    required this.minReceiveSat,
    required this.direction,
    super.referralId,
  });

  final int sendAmountSat;
  final int minReceiveSat;
  final ChainDirection direction;
}
