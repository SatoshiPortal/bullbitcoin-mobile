import 'package:flutter_dotenv/flutter_dotenv.dart';

class SettingsConstants {
  static const environmentKey = 'environment';
  static const bitcoinUnitKey = 'bitcoinUnit';
  static const languageKey = 'language';
  static const currencyKey = 'currency';
  static const hideAmountsKey = 'hideAmounts';
  static const blockstreamElectrumServerKeyPrefix = 'blockstreamElectrumServer';
  static const bullBitcoinElectrumServerKeyPrefix = 'bullBitcoinElectrumServer';
  static const customElectrumServerKeyPrefix = 'customElectrumServer';
  static const defaultCurrencyCode = 'CAD';
}

class ConversionConstants {
  static final satsAmountOfOneBitcoin = BigInt.from(100000000);
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
  static const labels = 'labels';
  static const labelsByRef = 'labelsByRef';
}

class PayjoinConstants {
  static const List<String> ohttpRelayUrls = [
    'https://ohttp.achow101.com',
    'https://pj.bobspacebkk.com',
  ];
  static const String directoryUrl = 'https://payjo.in';
  static const directoryPollingInterval = 5;
  static const defaultExpireAfterSec = 60 * 60 * 24; // 24 hours
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

  // BullBitcoin API

  static final bullBitcoinKeyServerApiUrlPath = dotenv.env['KEY_SERVER'] ??
      'http://o7rwmpnfkzdcay2gotla6sbrviu27wcgck7nsjrq77nqhtwbjvwcraad.onion';

  static String bbAuthUrl =
      '${dotenv.env['BB_AUTH_URL']}/en/registration?${dotenv.env['APIKEY_QUERY_PARAM']}';
}

class LocatorInstanceNameConstants {
  static const secureStorageDatasource = 'secureStorageDatasource';
  static const boltzSwapsHiveStorageDatasourceInstanceName =
      'boltzSwapsHiveStorageDatasource';
  static const boltzSwapRepositoryInstanceName = 'boltzSwapRepository';
  static const boltzTestnetSwapRepositoryInstanceName =
      'boltzTestnetSwapRepository';
  static const boltzSwapWatcherInstanceName = 'boltzSwapWatcher';
  static const boltzTestnetSwapWatcherInstanceName = 'boltzTestnetSwapWatcher';
  static const String labelsHiveStorageDatasourceInstanceName =
      'labelsHiveStorageDatasource';
  static const String labelByRefHiveStorageDatasourceInstanceName =
      'labelByRefHiveStorageDatasource';
  static const String lwkLiquidBlockchainDatasourceInstanceName =
      'lwkLiquidBlockchainDatasourceInstanceName';
  static const String bdkBitcoinBlockchainDatasourceInstanceName =
      'bdkBitcoinBlockchainDatasourceInstanceName';
}
