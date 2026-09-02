import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/passphrase_wallet/data/bdk_passphrase_wallet_deriver.dart';
import 'package:bb_mobile/features/passphrase_wallet/data/electrum_passphrase_wallet_scanner.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/create_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/forget_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/get_passphrase_wallets_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/prepare_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/scan_passphrase_wallet_balance_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/unlock_known_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/update_passphrase_wallet_metadata_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/presentation/passphrase_wallet_cubit.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:get_it/get_it.dart';

abstract final class PassphraseWalletLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<PassphraseWalletCubit>(() {
      final manifest = locator<KeychainManifestFacade>();
      final wallets = locator<WalletFacade>();
      final getWallets = GetPassphraseWalletsUsecase(
        locator<GetDefaultSeedUsecase>(),
        locator<GetSettingsUsecase>(),
        manifest,
      );
      return PassphraseWalletCubit(
        getWallets,
        PreparePassphraseWalletUsecase(
          locator<GetDefaultSeedUsecase>(),
          locator<GetSettingsUsecase>(),
          getWallets,
          const BdkPassphraseWalletDeriver(),
        ),
        UnlockKnownPassphraseWalletUsecase(wallets),
        CreatePassphraseWalletUsecase(manifest, wallets),
        ForgetPassphraseWalletUsecase(wallets, manifest),
        UpdatePassphraseWalletMetadataUsecase(manifest, wallets),
        ScanPassphraseWalletBalanceUsecase(
          ElectrumPassphraseWalletScanner(
            locator<BdkWalletDatasource>(),
            locator<ElectrumServersPort>(),
          ),
        ),
        wallets,
      );
    });
  }
}
