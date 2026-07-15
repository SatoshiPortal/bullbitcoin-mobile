import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';

/// The server's default LUD-22 proof value floor (sats). Used as the fallback
/// when a [BullpayProofRequiresProof] carries no explicit `min_sat`.
const int kBullpayDefaultMinProofValueSat = 1000;

/// Quiet fallback sentinel: the recipient is not a Bull LUD-22 direct-pay
/// target (metadata unavailable, no `L-BTC` method, SSRF-pin failure, no
/// qualifying UTXO, or a Lightning soft-fallback response). It is NOT a user
/// error — the send-cubit maps it to the normal Lightning swap and surfaces
/// nothing (DG-8). It is deliberately outside the sealed [BullpayProofError]
/// family so it can never be mistaken for a rendered payment error.
class LiquidDirectPayUnavailable implements Exception {
  const LiquidDirectPayUnavailable();
}

/// Sealed error family for the LUD-22 proof-of-funds callback (charter C1).
/// Every variant carries a localized [toTranslated] message; the raw server
/// `reason`/`code` stays for logs only and is never surfaced (charter C3).
///
/// Most variants are consumed as fallback triggers (mapped, logged, and then
/// replaced by the normal Lightning swap per DG-8); only a committed-rail
/// failure would ever render one of these.
sealed class BullpayProofError extends BullException {
  BullpayProofError._(super.message);

  /// Maps the server's stable error codes (`bullnym src/error.rs`) to the
  /// matching variant. The prototype's `RateLimited` /
  /// `TooManyPendingReservations` codes are gone on the L-BTC path — a soft
  /// limit returns a Lightning invoice instead, handled as a decline (DG-8),
  /// so there is no variant for them here.
  factory BullpayProofError.fromServerCode({
    required String code,
    String? reason,
    int? minSat,
  }) {
    switch (code) {
      case 'ProofOfFundsRequired':
        return BullpayProofRequiresProof(minSat: minSat);
      case 'ProofOfFundsInvalid':
        return BullpayProofInvalid(reason: reason);
      case 'UtxoNotFound':
        return BullpayProofUtxoNotFound(reason: reason);
      case 'UtxoSpent':
        return BullpayProofUtxoSpent(reason: reason);
      case 'PubkeyUtxoMismatch':
        return BullpayProofPubkeyMismatch(reason: reason);
      case 'InvalidAmount':
        return BullpayProofInvalidAmount(reason: reason);
      case 'NymNotFound':
        return BullpayProofNymNotFound(reason: reason);
      default:
        return BullpayProofInternal(code);
    }
  }

  String toTranslated(BuildContext context) {
    return switch (this) {
      BullpayProofRequiresProof(:final minSat) => context.loc.sendLud22MinValue(
        minSat ?? kBullpayDefaultMinProofValueSat,
      ),
      BullpayProofInvalid() => context.loc.sendLud22InvalidProof,
      BullpayProofPubkeyMismatch() => context.loc.sendLud22InvalidProof,
      BullpayProofUtxoNotFound() => context.loc.sendLud22UtxoUnavailable,
      BullpayProofUtxoSpent() => context.loc.sendLud22UtxoUnavailable,
      BullpayProofNymNotFound() => context.loc.sendLud22NymNotFound,
      BullpayProofInvalidAmount() => context.loc.sendLud22DirectPayFailed,
      BullpayProofInternal() => context.loc.sendLud22DirectPayFailed,
    };
  }
}

/// `ProofOfFundsRequired`: the server needs a proof of funds (no valid one was
/// sent, or the value is below the floor). Carries the server's `min_sat`.
final class BullpayProofRequiresProof extends BullpayProofError {
  final int? minSat;
  BullpayProofRequiresProof({this.minSat})
    : super._('bullpay proof of funds required');
}

/// `ProofOfFundsInvalid`: the DG-7 hard code — unblinding failed, the asset is
/// not L-BTC, the value is below the floor, or the opening was forged.
final class BullpayProofInvalid extends BullpayProofError {
  final String? reason;
  BullpayProofInvalid({this.reason})
    : super._('bullpay proof of funds invalid');
}

/// `UtxoNotFound`: the server's chain view has not seen the proof outpoint.
final class BullpayProofUtxoNotFound extends BullpayProofError {
  final String? reason;
  BullpayProofUtxoNotFound({this.reason})
    : super._('bullpay proof utxo not found');
}

/// `UtxoSpent`: the proof outpoint is already spent (the client's UTXO set is
/// stale). Do not retry the same outpoint — fall back.
final class BullpayProofUtxoSpent extends BullpayProofError {
  final String? reason;
  BullpayProofUtxoSpent({this.reason}) : super._('bullpay proof utxo spent');
}

/// `PubkeyUtxoMismatch`: the proof pubkey does not control the outpoint.
final class BullpayProofPubkeyMismatch extends BullpayProofError {
  final String? reason;
  BullpayProofPubkeyMismatch({this.reason})
    : super._('bullpay proof pubkey utxo mismatch');
}

/// `InvalidAmount`: the callback amount is not a valid msat multiple / out of
/// the sendable range. Impossible from a sat-denominated UI.
final class BullpayProofInvalidAmount extends BullpayProofError {
  final String? reason;
  BullpayProofInvalidAmount({this.reason})
    : super._('bullpay proof invalid amount');
}

/// `NymNotFound`: the recipient nym is not registered on the server.
final class BullpayProofNymNotFound extends BullpayProofError {
  final String? reason;
  BullpayProofNymNotFound({this.reason})
    : super._('bullpay proof nym not found');
}

/// Catch-all for any unrecognised server code. The raw [code] is kept for logs
/// only; the user sees the generic localized copy (charter C3).
final class BullpayProofInternal extends BullpayProofError {
  final String code;
  BullpayProofInternal(this.code) : super._('bullpay proof internal: $code');
}
