import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/hive_storage_datasource_impl.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/repository/bitcoin_wallet_repository_impl.dart';
import 'package:bb_mobile/core/wallet/data/repository/liquid_wallet_repository_impl.dart';
import 'package:bb_mobile/core/wallet/data/repository/wallet_repository_impl.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:bb_mobile/locator.dart';
import 'package:hive/hive.dart';

class WalletLocator {
  static Future<void> registerDatasourceres() async {
    locator.registerLazySingleton<BdkWalletDatasource>(
      () => const BdkWalletDatasource(),
    );
    locator.registerLazySingleton<LwkWalletDatasource>(
      () => const LwkWalletDatasource(),
    );
    final walletMetadataBox =
        await Hive.openBox<String>(HiveBoxNameConstants.walletMetadata);
    locator.registerLazySingleton<WalletMetadataDatasource>(
      () => WalletMetadataDatasource(
        walletMetadataStorage:
            HiveStorageDatasourceImpl<String>(walletMetadataBox),
      ),
    );
  }

  static void registerRepositories() {
    locator.registerLazySingleton<BitcoinWalletRepository>(
      () => BitcoinWalletRepositoryImpl(
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        bdkWalletDatasource: locator<BdkWalletDatasource>(),
        seedDatasource: locator<SeedDatasource>(),
      ),
    );

    locator.registerLazySingleton<LiquidWalletRepository>(
      () => LiquidWalletRepositoryImpl(
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        seedDatasource: locator<SeedDatasource>(),
        lwkWalletDatasource: locator<LwkWalletDatasource>(),
      ),
    );

    locator.registerLazySingleton<WalletRepository>(
      () => WalletRepositoryImpl(
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        bdkWalletDatasource: locator<BdkWalletDatasource>(),
        lwkWalletDatasource: locator<LwkWalletDatasource>(),
        electrumServerStorageDatasource:
            locator<ElectrumServerStorageDatasource>(),
      ),
    );
  }
}
