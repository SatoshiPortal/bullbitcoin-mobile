import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/activate_bip85_derivation_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/alias_bip85_derivation_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_hex_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_mnemonic_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/fetch_all_bip85_derivations_with_entropy_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/revoke_bip85_derivation_usecase.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/bip85_entropy/domain/can_access_bip85_entropy_usecase.dart';
import 'package:bb_mobile/features/bip85_entropy/domain/derive_next_unreserved_bip85_mnemonic_usecase.dart';
import 'package:bb_mobile/features/bip85_entropy/domain/fetch_unreserved_bip85_derivations_with_entropy_usecase.dart';
import 'package:bb_mobile/features/bip85_entropy/presentation/cubit.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:get_it/get_it.dart';

class Bip85EntropyLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<FetchAllBip85DerivationsWithEntropyUsecase>(
      () => FetchAllBip85DerivationsWithEntropyUsecase(
        bip85Repository: locator<Bip85Repository>(),
        getDefaultSeedUsecase: locator<GetDefaultSeedUsecase>(),
      ),
    );

    locator.registerFactory<FetchUnreservedBip85DerivationsWithEntropyUsecase>(
      () => FetchUnreservedBip85DerivationsWithEntropyUsecase(
        fetchAll: locator<FetchAllBip85DerivationsWithEntropyUsecase>(),
        registry: locator<Bip85RegistryFacade>(),
      ),
    );

    locator.registerFactory<DeriveNextUnreservedBip85MnemonicUsecase>(
      () => DeriveNextUnreservedBip85MnemonicUsecase(
        deriveNext: locator<DeriveNextBip85MnemonicFromDefaultWalletUsecase>(),
        registry: locator<Bip85RegistryFacade>(),
      ),
    );

    locator.registerFactory<CanAccessBip85EntropyUsecase>(
      () => CanAccessBip85EntropyUsecase(
        getSettings: locator<GetSettingsUsecase>(),
      ),
    );

    locator.registerFactory<Bip85EntropyCubit>(
      () => Bip85EntropyCubit(
        fetchUnreservedBip85DerivationsWithEntropyUsecase:
            locator<FetchUnreservedBip85DerivationsWithEntropyUsecase>(),
        deriveNextUnreservedBip85MnemonicUsecase:
            locator<DeriveNextUnreservedBip85MnemonicUsecase>(),
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
