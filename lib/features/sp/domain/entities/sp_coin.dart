import 'package:primitives/primitives.dart';

/// The sub-account a coin belongs to. Domain mirror of the bwk `CoinSource`
/// FFI enum.
enum SpCoinSource { sp, segwit, taproot, other }

/// Confirmation/spend state of a coin. Domain mirror of the bwk
/// `UnifiedCoinStatus` FFI enum.
enum SpCoinStatus { unconfirmed, unspent, spent }

/// One unified coin across the SP and taproot sub-accounts. Domain mirror of
/// the bwk `UnifiedCoinView` FFI struct; the wire type stays in `data/` behind
/// `SpCoinMapper`.
class SpCoin {
  final SpCoinSource source;
  final Outpoint outpoint;
  final Sats amountSat;
  final int? height;
  final SpCoinStatus status;

  SpCoin({
    required this.source,
    required this.outpoint,
    required this.amountSat,
    this.height,
    required this.status,
  }) {
    if (outpoint.txId.isEmpty) {
      throw ArgumentError.value(outpoint, 'outpoint', 'txId must not be empty');
    }
    if (outpoint.vout < 0) {
      throw ArgumentError.value(
        outpoint,
        'outpoint',
        'vout must not be negative',
      );
    }
    if (height != null && height! < 0) {
      throw ArgumentError.value(height, 'height', 'must not be negative');
    }
    // Deliberately no status/height cross-check: bwk decides when a coin
    // carries a block, and asserting a relationship here would turn a change on
    // its side into a crash on ours.
  }
}
