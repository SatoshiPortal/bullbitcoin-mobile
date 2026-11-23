/// Values used by published legacy migrations and schema-16 creation.
abstract final class HistoricalDefaults {
  static const fulcrumElectrumUrl = 'ssl://fulcrum.bullbitcoin.com:50002';
  static const bbElectrumUrl = 'ssl://wes.bullbitcoin.com:50002';
  static const bbLiquidElectrumUrlPath = 'les.bullbitcoin.com:995';
  static const publicElectrumUrl =
      'ssl://bitcoin-mainnet.blockstream.info:50002';
  static const publicLiquidElectrumUrlPath =
      'elements-mainnet.blockstream.info:50002';
  static const publicElectrumTestUrl =
      'ssl://bitcoin-testnet.blockstream.info:50002';
  static const publicliquidElectrumTestUrlPath =
      'elements-testnet.blockstream.info:50002';
  static const bbMempoolUrlPath = 'mempool.bullbitcoin.com';
  static const testnetMempoolUrlPath = 'mempool.space/testnet';
  static const bbLiquidMempoolUrlPath = 'liquid.bullbitcoin.com';
  static const bbLiquidMempoolTestnetUrlPath = 'liquid.bullbitcoin.com/testnet';
  static const recoverbullUrl =
      'http://5m7enm5y77tdgmaf3d5xuwa5c7fjma7v5ljtwxu4q5jtq6b5utspmpyd.onion';
}
