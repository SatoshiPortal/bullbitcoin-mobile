class SettingsConstants {
  static const environmentKey = 'environment';
  static const bitcoinUnitKey = 'bitcoinUnit';
  static const languageKey = 'language';
  static const currencyKey = 'currency';
  static const electrumServerKeyPrefix = 'electrumServer';
  static const defaultCurrencyCode = 'CAD';
}

class SecureStorageKeyPrefixConstants {
  static const seed = 'seed_';
  static const swap = 'swap_';
}

class HiveBoxNameConstants {
  static const settings = 'settings';
  static const electrumServers = 'electrumServers';
  static const walletMetadata = 'walletMetadata';
  static const pdkPayjoins = 'pdkPayjoins';
  static const boltzSwaps = 'boltzSwaps';
}

class PayjoinConstants {
  static const String ohttpRelayUrl = 'https://pj.bobspacebkk.com';
  static const String directoryUrl = 'https://payjo.in';
  static const directoryPollingInterval = 5;
}

class ApiServiceConstants {
  // Bitcoin mempool
  static const bbMempoolUrlPath = 'mempool.bullbitcoin.com';
  static const publicMempoolUrlPath = 'mempool.space';

  // Liquid mempool
  static const publicLiquidMempoolUrl = 'https://liquid.network';
  static const publicLiquidMempoolTestnetUrl = 'https://liquid.network/testnet';

  // BullBitcoin Exchange
  static const bbExchangeUrlPath = 'api.bullbitcoin.com/price';
  // final bbExchangeUrlPath = 'pricer.bullbitcoin.dev/api';

  // Bitcoin Electrum servers
  static const bbElectrumUrl = 'ssl://wes.bullbitcoin.com:50002';
  static const publicElectrumUrl = 'ssl://blockstream.info:700';
  // BB test currently not operational
  static const bbElectrumTestUrl = 'ssl://wes.bullbitcoin.com:60002';
  static const publicElectrumTestUrl = 'ssl://blockstream.info:993';

  // Liquid Electrum servers
  static const bbLiquidElectrumUrlPath = 'les.bullbitcoin.com:995';
  static const bbLiquidElectrumTestUrlPath = 'blockstream.info:465';
  static const publicLiquidElectrumUrlPath = 'blockstream.info:995';
  static const publicliquidElectrumTestUrlPath = 'blockstream.info:465';

  // Boltz API
  static const boltzMainnetUrlPath = 'api.boltz.exchange/v2';
  static const boltzTestnetUrlPath = 'api.testnet.boltz.exchange/v2';
}

class LocatorInstanceNameConstants {
  static const secureStorageDataSource = 'secureStorageDataSource';
  static const bullBitcoinExchangeDataSourceInstanceName =
      'bullBitcoinExchangeDataSource';
  static const boltzSwapsHiveStorageDataSourceInstanceName =
      'boltzSwapsHiveStorageDataSource';
  static const boltzSwapRepositoryInstanceName = 'boltzSwapRepository';
  static const boltzTestnetSwapRepositoryInstanceName =
      'boltzTestnetSwapRepository';
}
