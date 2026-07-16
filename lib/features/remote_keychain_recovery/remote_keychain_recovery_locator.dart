import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/keychain_recovery/public/keychain_recovery_facade.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/payment_page/public/payment_page_facade.dart';
import 'package:bb_mobile/features/pos/public/pos_facade.dart';
import 'package:bb_mobile/features/remote_keychain_recovery/domain/recover_remote_keychain_manifest_usecase.dart';
import 'package:bb_mobile/features/remote_keychain_recovery/domain/usecases/heal_recovered_products_usecase.dart';
import 'package:bb_mobile/features/remote_keychain_recovery/domain/usecases/recover_remote_wallet_backups_usecase.dart';
import 'package:bb_mobile/features/remote_keychain_recovery/public/remote_keychain_recovery_facade.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/public/wallet_metadata_backup_facade.dart';
import 'package:get_it/get_it.dart';

final class RemoteKeychainRecoveryLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<HealRecoveredProductsUsecase>(
      () => HealRecoveredProductsUsecase(
        locator<LightningAddressFacade>(),
        locator<PaymentPageFacade>(),
        locator<PosFacade>(),
      ),
    );
    locator.registerFactory<RecoverRemoteKeychainManifestUsecase>(
      () => RecoverRemoteKeychainManifestUsecase(
        manifest: locator<KeychainManifestFacade>(),
        recovery: locator<KeychainRecoveryFacade>(),
        healRecoveredProducts: locator<HealRecoveredProductsUsecase>(),
      ),
    );
    locator.registerFactory<RecoverRemoteWalletBackupsUsecase>(
      () => RecoverRemoteWalletBackupsUsecase(
        () => locator<RecoverRemoteKeychainManifestUsecase>().execute(),
        locator<WalletMetadataBackupFacade>(),
      ),
    );
    locator.registerFactory<RemoteKeychainRecoveryFacade>(
      () => RemoteKeychainRecoveryFacade(
        locator<RecoverRemoteWalletBackupsUsecase>(),
      ),
    );
  }
}
