import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/activate_bip85_derivation_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/alias_bip85_derivation_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_hex_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_mnemonic_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/fetch_all_bip85_derivations_with_entropy_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/revoke_bip85_derivation_usecase.dart';
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/features/bip85_entropy/presentation/cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class Bip85EntropyLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<FetchAllBip85DerivationsWithEntropyUsecase>(
      () => FetchAllBip85DerivationsWithEntropyUsecase(
        bip85Repository: locator<Bip85Repository>(),
        secrets: locator<Secrets>(),
        walletRepository: locator<WalletRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<Bip85EntropyCubit>(
      () => Bip85EntropyCubit(
        fetchAllBip85DerivationsWithEntropyUsecase:
            locator<FetchAllBip85DerivationsWithEntropyUsecase>(),
        deriveNextBip85MnemonicFromDefaultWalletUsecase:
            locator<DeriveNextBip85MnemonicFromDefaultWalletUsecase>(),
        deriveNextBip85HexFromDefaultWalletUsecase:
            locator<DeriveNextBip85HexFromDefaultWalletUsecase>(),
        aliasBip85DerivationUsecase: locator<AliasBip85DerivationUsecase>(),
        revokeBip85DerivationUsecase: locator<RevokeBip85DerivationUsecase>(),
        activateBip85DerivationUsecase:
            locator<ActivateBip85DerivationUsecase>(),
      ),
    );
  }
}
