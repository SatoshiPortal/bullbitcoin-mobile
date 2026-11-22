abstract final class ElectrumDefaultEndpoints {
  // Bitcoin Electrum servers
  static const fulcrumElectrumUrl = 'ssl://fulcrum.bullbitcoin.com:50002';
  static const bbElectrumUrl = 'ssl://wes.bullbitcoin.com:50002';
  static const publicElectrumUrl =
      'ssl://bitcoin-mainnet.blockstream.info:50002';
  static const publicElectrumTestUrl =
      'ssl://bitcoin-testnet.blockstream.info:50002';

  // Liquid Electrum servers - lwk does not accept ssl:// prefix
  static const bbLiquidElectrumUrlPath = 'les.bullbitcoin.com:995';
  static const publicLiquidElectrumUrlPath =
      'elements-mainnet.blockstream.info:50002';
  static const publicliquidElectrumTestUrlPath =
      'elements-testnet.blockstream.info:50002';
}
