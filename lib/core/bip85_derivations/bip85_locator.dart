import 'package:bb_mobile/core/bip85_derivations/data/bip85_datasource.dart';
import 'package:bb_mobile/core/bip85_derivations/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85_derivations/domain/derive_next_bip85_hex_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85_derivations/domain/derive_next_bip85_mnemonic_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/locator.dart';

class Bip85DerivationsLocator {
  static Future<void> registerDatasources() async {
    locator.registerLazySingleton<Bip85Datasource>(
      () => Bip85Datasource(sqlite: locator<SqliteDatabase>()),
    );
  }

  static Future<void> registerRepositories() async {
    locator.registerLazySingleton<Bip85Repository>(
      () => Bip85Repository(datasource: locator<Bip85Datasource>()),
    );
  }

  static void registerUsecases() {
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
  }
}
