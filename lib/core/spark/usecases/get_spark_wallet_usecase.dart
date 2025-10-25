import 'package:bb_mobile/core/seed/domain/entity/seed.dart' as app_seed;
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/spark/entities/spark_wallet.dart';
import 'package:bb_mobile/core/spark/errors.dart';
import 'package:bb_mobile/core/spark/spark.dart';
import 'package:breez_sdk_spark_flutter/breez_sdk_spark.dart';
import 'package:path_provider/path_provider.dart';

class GetSparkWalletUsecase {
  final GetDefaultSeedUsecase _getDefaultSeedUsecase;
  final SettingsRepository _settingsRepository;

  SparkWalletEntity? _cachedWallet;

  GetSparkWalletUsecase({
    required GetDefaultSeedUsecase getDefaultSeedUsecase,
    required SettingsRepository settingsRepository,
  }) : _getDefaultSeedUsecase = getDefaultSeedUsecase,
       _settingsRepository = settingsRepository;

  Future<SparkWalletEntity?> execute({bool forceRefresh = false}) async {
    try {
      if (_cachedWallet != null && !forceRefresh) {
        return _cachedWallet;
      }

      final settings = await _settingsRepository.fetch();
      if (settings.isDevModeEnabled != true) {
        return null;
      }

      final defaultSeed = await _getDefaultSeedUsecase.execute();

      // Extract mnemonic words
      final String mnemonicString;
      if (defaultSeed is app_seed.MnemonicSeed) {
        mnemonicString = defaultSeed.mnemonicWords.join(' ');
      } else {
        // If seed is bytes-only, we can't use it with Spark
        throw SparkError('Spark requires a mnemonic-based seed');
      }

      final seed = Seed.mnemonic(mnemonic: mnemonicString, passphrase: null);

      final config = defaultConfig(
        network: Spark.network,
      ).copyWith(apiKey: Spark.apiKey);

      final appDir = await getApplicationDocumentsDirectory();
      final storageDir = '${appDir.path}/${Spark.storageDir}';

      final connectRequest = ConnectRequest(
        config: config,
        seed: seed,
        storageDir: storageDir,
      );

      final sdk = await connect(request: connectRequest);

      return _cachedWallet = SparkWalletEntity(sdk: sdk);
    } catch (e) {
      throw SparkError('Failed to initialize Spark wallet: $e');
    }
  }

  void clearCache() {
    _cachedWallet = null;
  }
}
