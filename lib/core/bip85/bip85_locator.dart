import 'package:bb_mobile/core/bip85/data/bip85_datasource.dart';
import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_hex_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_mnemonic_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/fetch_all_derivations_usecase.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:get_it/get_it.dart';

class Bip85DerivationsLocator {
  static void registerDatasources(GetIt locator) {
    locator.registerLazySingleton<Bip85Datasource>(
      () => Bip85Datasource(sqlite: locator<SqliteDatabase>()),
    );
  }

  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<Bip85Repository>(
      () => Bip85Repository(datasource: locator<Bip85Datasource>()),
    );
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<DeriveNextBip85HexFromDefaultWalletUsecase>(
      () => DeriveNextBip85HexFromDefaultWalletUsecase(
        bip85Repository: locator<Bip85Repository>(),
        walletRepository: locator<WalletRepository>(),
        seedRepository: locator<SeedRepository>(),
      ),
    );

    locator.registerFactory<DeriveNextBip85MnemonicFromDefaultWalletUsecase>(
      () => DeriveNextBip85MnemonicFromDefaultWalletUsecase(
        bip85Repository: locator<Bip85Repository>(),
        walletRepository: locator<WalletRepository>(),
        seedRepository: locator<SeedRepository>(),
      ),
    );

    locator.registerFactory<FetchAllBip85DerivationsUsecase>(
      () => FetchAllBip85DerivationsUsecase(
        bip85Repository: locator<Bip85Repository>(),
      ),
    );
  }
}
