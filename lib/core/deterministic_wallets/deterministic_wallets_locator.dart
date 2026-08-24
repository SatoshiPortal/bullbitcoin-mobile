import 'package:bb_mobile/core/bip85/domain/derive_bip85_mnemonic_at_index_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/deterministic_wallets/prepare_deterministic_wallets_usecase.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:get_it/get_it.dart';

abstract final class DeterministicWalletsLocator {
  static void registerUsecase(GetIt locator) {
    locator.registerFactory<PrepareDeterministicWalletsUsecase>(
      () => PrepareDeterministicWalletsUsecase(
        locator<DeriveBip85MnemonicAtIndexFromDefaultWalletUsecase>(),
        walletRepository: locator<WalletRepository>(),
        seedRepository: locator<SeedRepository>(),
      ),
    );
  }
}
