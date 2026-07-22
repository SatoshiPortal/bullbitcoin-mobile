/// An explicit Liquid transaction output — an address, an amount, and
/// (optionally) which asset. `null` [assetId] means the policy asset (L-BTC).
///
/// Lives in `domain/` so repository contracts speak it instead of the raw SDK
/// wire type (the boundary rule) — mirrors `lwk`'s `TxOutputSpec`, converted
/// to/from it only inside `data/`.
class LiquidTxOutput {
  final String address;
  final int satoshi;
  final String? assetId;

  const LiquidTxOutput({
    required this.address,
    required this.satoshi,
    this.assetId,
  });
}
