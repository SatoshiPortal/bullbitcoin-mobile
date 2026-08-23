import 'package:bb_mobile/core/bip85/domain/derive_bip85_mnemonic_at_index_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/deterministic_wallets/data/deterministic_wallet_repository_impl.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/prepare_deterministic_wallets_usecase.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/repositories/deterministic_wallet_repository.dart';
import 'package:bb_mobile/features/deterministic_wallets/public/deterministic_wallets_facade.dart';
import 'package:get_it/get_it.dart';

abstract final class DeterministicWalletsLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<DeterministicWalletRepository>(
      () => DeterministicWalletRepositoryImpl(
        walletRepository: locator<WalletRepository>(),
        seedRepository: locator<SeedRepository>(),
      ),
    );
    locator.registerFactory<PrepareDeterministicWalletsUsecase>(
      () => PrepareDeterministicWalletsUsecase(
        locator<DeriveBip85MnemonicAtIndexFromDefaultWalletUsecase>(),
        locator<DeterministicWalletRepository>(),
      ),
    );
    locator.registerFactory(
      () => DeterministicWalletsFacade(
        locator<PrepareDeterministicWalletsUsecase>(),
      ),
    );
  }
}
