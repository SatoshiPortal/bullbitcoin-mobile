import 'package:electrum/setup.dart' show ElectrumDefaultEndpoints;
import 'package:material_ui/material_ui.dart';

class Device {
  static late Size screen;

  static void init(BuildContext context) {
    screen = MediaQuery.of(context).size;
  }
}

class SettingsConstants {
  static const telegramSupportLink = 'https://t.me/+gUHV3ZcQ-_RmZDdh';
  static const webSupportLink = 'https://app.bullbitcoin.com/support';
  static const githubSupportLink =
      'https://github.com/SatoshiPortal/bullbitcoin-mobile';
  static const termsAndConditionsLink = 'https://wallet.bullbitcoin.com/terms';
  static const exchangeTermsAndConditionsLink =
      'https://www.bullbitcoin.com/terms';
  static const recoverbullUrl =
      'http://5m7enm5y77tdgmaf3d5xuwa5c7fjma7v5ljtwxu4q5jtq6b5utspmpyd.onion';
}

class ConversionConstants {
  static final satsAmountOfOneBitcoin = BigInt.from(100_000_000);
  static final maxBitcoinAmount = BigInt.from(21_000_000); // 21 million BTC
  static final maxSatsAmount = maxBitcoinAmount * satsAmountOfOneBitcoin;
}

class SecureStorageKeyPrefixConstants {
  static const seed = 'seed_';
  static const swap = 'swap_';
  static const swapMasterKey = 'swap_master_key_';
  // Fresh key (the old `swap_key_index_` was seeded high by a now-removed bug);
  // this resets the per-network swap index counter to 0.
  static const swapKeyIndex = 'swap_master_key_index_';
}

class AssetConstants {
  static const lbtcMainnet =
      '6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d';
  static const lbtcTestnet =
      '144c654344aa716d6f3abcc1ca90e5641e4e2a7f633bc09fe3baf64585819a49';
}

class ApiServiceConstants {
  // Bitcoin mempool
  static const bbMempoolUrlPath = 'mempool.bullbitcoin.com';
  static const publicMempoolUrlPath = 'mempool.space'; // note: not used
  static const testnetMempoolUrlPath = 'mempool.space/testnet';

  // Liquid mempool
  static const bbLiquidMempoolUrlPath = 'liquid.bullbitcoin.com';
  static const bbLiquidMempoolTestnetUrlPath = 'liquid.bullbitcoin.com/testnet';
  static const publicLiquidMempoolUrl =
      'https://liquid.network'; // note: not used
  static const publicLiquidMempoolTestnetUrl =
      'https://liquid.network/testnet'; // note: not used

  // Historical migrations reference these defaults.
  static const fulcrumElectrumUrl = ElectrumDefaultEndpoints.fulcrumElectrumUrl;
  static const bbElectrumUrl = ElectrumDefaultEndpoints.bbElectrumUrl;
  static const publicElectrumUrl = ElectrumDefaultEndpoints.publicElectrumUrl;
  static const publicElectrumTestUrl =
      ElectrumDefaultEndpoints.publicElectrumTestUrl;
  static const bbLiquidElectrumUrlPath =
      ElectrumDefaultEndpoints.bbLiquidElectrumUrlPath;
  static const publicLiquidElectrumUrlPath =
      ElectrumDefaultEndpoints.publicLiquidElectrumUrlPath;
  static const publicliquidElectrumTestUrlPath =
      ElectrumDefaultEndpoints.publicliquidElectrumTestUrlPath;

  // Boltz API
  static const boltzMainnetUrlPath = 'api.boltz.exchange/v2';
  static const boltzTestnetUrlPath = 'api.testnet.boltz.exchange/v2';
  static const boltzReferralId = 'BULL';

  // BullBitcoin API
  static const String bbApiUrl = 'https://api.bullbitcoin.com';
  static const String bbApiTestUrl = 'https://api05.bullbitcoin.dev';
  static const String bbAuthUrl = 'https://accounts.bullbitcoin.com';
  static const String bbAuthTestUrl = 'https://accounts05.bullbitcoin.dev';
  static const String bbAppUrl = 'https://app.bullbitcoin.com';
  static const String bbKycUrl = 'https://app.bullbitcoin.com/kyc';
  static const String bbKycTestUrl = 'https://bbx05.bullbitcoin.dev/kyc';
  static const String swapApiStagingUrl = 'https://staging.boltzbackup.com';
  static const String swapApiMainnetUrl = 'https://api.boltzbackup.com';
  static const String googleDriveClientId =
      '97584343569-0mc4e5q9q1qino4vvo97mqomdi89sae5.apps.googleusercontent.com';

  // Error reports
  static const String sentryDsn =
      'https://b6a8d5134da043eda72f231891c6e51a@cc.bullbitcoin.com/1';
}

class LocatorInstanceNameConstants {
  static const boltzSwapsHiveStorageDatasourceInstanceName =
      'boltzSwapsHiveStorageDatasource';
  static const boltzAutoSwapTimerInstanceName = 'boltzAutoSwapTimer';
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
