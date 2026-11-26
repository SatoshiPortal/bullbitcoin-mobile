export 'src/data/mempool_import.dart' show MempoolImport;

/// Endpoint values shared by the published legacy migrations and import.
abstract final class MempoolLegacyDefaults {
  static const bbMempoolUrlPath = 'mempool.bullbitcoin.com';
  static const testnetMempoolUrlPath = 'mempool.space/testnet';
  static const bbLiquidMempoolUrlPath = 'liquid.bullbitcoin.com';
  static const bbLiquidMempoolTestnetUrlPath = 'liquid.bullbitcoin.com/testnet';
}
