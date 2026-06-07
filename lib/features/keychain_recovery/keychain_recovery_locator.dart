import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/deterministic_wallets/public/deterministic_wallets_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/keychain_recovery/application/ports/keychain_recovery_wallet_materializer_port.dart';
import 'package:bb_mobile/features/keychain_recovery/application/usecases/restore_keychain_manifest_wallets_usecase.dart';
import 'package:bb_mobile/features/keychain_recovery/frameworks/deterministic_wallet_recovery_materializer.dart';
import 'package:bb_mobile/features/keychain_recovery/public/keychain_recovery_facade.dart';
import 'package:get_it/get_it.dart';

class KeychainRecoveryLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<KeychainRecoveryWalletMaterializerPort>(
      () => DeterministicWalletRecoveryMaterializer(
        deterministicWallets: locator<DeterministicWalletsFacade>(),
        getSettings: locator<GetSettingsUsecase>(),
      ),
    );
    locator.registerFactory<RestoreKeychainManifestWalletsUsecase>(
      () => RestoreKeychainManifestWalletsUsecase(
        walletMaterializer: locator<KeychainRecoveryWalletMaterializerPort>(),
        keychainManifest: locator<KeychainManifestFacade>(),
        bip85Registry: locator<Bip85RegistryFacade>(),
      ),
    );
    locator.registerFactory<KeychainRecoveryFacade>(
      () => KeychainRecoveryFacade(
        restoreWallets: locator<RestoreKeychainManifestWalletsUsecase>(),
      ),
    );
  }
}
