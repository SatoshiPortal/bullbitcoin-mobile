import 'package:flutter_dotenv/flutter_dotenv.dart';

class SettingsConstants {
  static const telegramSupportLink = 'https://t.me/+gUHV3ZcQ-_RmZDdh';
  static const githubSupportLink =
      'https://github.com/SatoshiPortal/bullbitcoin-mobile';
  static const termsAndConditionsLink = 'https://bullbitcoin.com/privacy';
  // The following are constants that in the future potentially can become
  //  a configurable setting, in which case they should be added to the Settings
  //  table in sqlite and not be defined here as constants anymore.
  static const autoSyncIntervalSeconds = 5;
}

class ConversionConstants {
  static final satsAmountOfOneBitcoin = BigInt.from(100_000_000);
  static final maxBitcoinAmount = BigInt.from(21_000_000); // 21 million BTC
  static final maxSatsAmount = maxBitcoinAmount * satsAmountOfOneBitcoin;
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

class AssetConstants {
  static const lbtcMainnet =
      '6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d';
  static const lbtcTestnet =
      '144c654344aa716d6f3abcc1ca90e5641e4e2a7f633bc09fe3baf64585819a49';
}

class PayjoinConstants {
  static const List<String> ohttpRelayUrls = [
    'https://ohttp.achow101.com',
    'https://pj.bobspacebkk.com',
    'https://ohttp.cakewallet.com',
  ];
  static const String directoryUrl = 'https://payjo.in';
  static const directoryPollingInterval = 5;
  static const defaultExpireAfterSec = 60 * 60 * 24; // 24 hours
}

class ApiServiceConstants {
  // Bitcoin mempool
  static const bbMempoolUrlPath = 'mempool.bullbitcoin.com';
  static const publicMempoolUrlPath = 'mempool.space';
  static const testnetMempoolUrlPath = 'mempool.space/testnet';

  // Liquid mempool
  static const bbLiquidMempoolUrlPath = 'liquid.bullbitcoin.com';
  static const bbLiquidMempoolTestnetUrlPath = 'liquid.bullbitcoin.com/testnet';
  static const publicLiquidMempoolUrl = 'https://liquid.network';
  static const publicLiquidMempoolTestnetUrl = 'https://liquid.network/testnet';

  // Bitcoin Electrum servers
  static const bbElectrumUrl = 'ssl://wes.bullbitcoin.com:50002';
  static const publicElectrumUrl = 'ssl://blockstream.info:700';
  // BB test currently not operational
  static const bbElectrumTestUrl = 'ssl://wes.bullbitcoin.com:60002';
  static const publicElectrumTestUrl = 'ssl://blockstream.info:993';

  // Liquid Electrum servers - lwk does not accept ssl:// prefix
  static const bbLiquidElectrumUrlPath = 'les.bullbitcoin.com:995';
  static const bbLiquidElectrumTestUrlPath = 'les.bullbitcoin.com:465';
  static const publicLiquidElectrumUrlPath = 'blockstream.info:995';
  static const publicliquidElectrumTestUrlPath = 'blockstream.info:465';

  // Boltz API
  static const boltzMainnetUrlPath = 'api.boltz.exchange/v2';
  static const boltzTestnetUrlPath = 'api.testnet.boltz.exchange/v2';

  // BullBitcoin API
  static final bullBitcoinKeyServerApiUrlPath =
      dotenv.env['KEY_SERVER'] ??
      'http://o7rwmpnfkzdcay2gotla6sbrviu27wcgck7nsjrq77nqhtwbjvwcraad.onion';
  static String bbApiUrl =
      dotenv.env['BB_API_URL'] ?? 'https://api.bullbitcoin.com';
  static String bbApiTestUrl =
      dotenv.env['BB_API_TEST_URL'] ?? 'https://api05.bullbitcoin.dev';
  static String bbAuthUrl = 'https://${dotenv.env['BB_AUTH_URL']}';
  static String bbAuthTestUrl = 'https://${dotenv.env['BB_AUTH_TEST_URL']}';
  static String bbKycUrl = 'https://app.bullbitcoin.com/kyc';
  static String bbKycTestUrl = 'https://bbx05.bullbitcoin.dev/kyc';
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
  static const boltzAutoSwapTimerInstanceName = 'boltzAutoSwapTimer';
  static const boltzTestnetAutoSwapTimerInstanceName =
      'boltzTestnetAutoSwapTimer';
  static const String labelsHiveStorageDatasourceInstanceName =
      'labelsHiveStorageDatasource';
  static const String labelByRefHiveStorageDatasourceInstanceName =
      'labelByRefHiveStorageDatasource';
  static const String lwkLiquidBlockchainDatasourceInstanceName =
      'lwkLiquidBlockchainDatasourceInstanceName';
  static const String bdkBitcoinBlockchainDatasourceInstanceName =
      'bdkBitcoinBlockchainDatasourceInstanceName';
  static const String bullBitcoinAPIKeyDatasourceInstanceName =
      'bullBitcoinAPIKeyDatasourceInstanceName';
}

class LabelConstants {
  static const separator = '␟';
  static const labelKeyPrefix = 'label';
}
