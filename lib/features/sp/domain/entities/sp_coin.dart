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
  final String outpoint;
  final BigInt amountSat;
  final int? height;
  final SpCoinStatus status;

  const SpCoin({
    required this.source,
    required this.outpoint,
    required this.amountSat,
    this.height,
    required this.status,
  });
}
