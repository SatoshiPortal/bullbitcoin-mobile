import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/features/wallet/data/bitcoin_wallet_repository.dart';
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_wallet_status_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_wallet_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/scan_mnemonic_usecase.dart';

class ImportMnemonicLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<CheckDuplicateMnemonicUsecase>(
      () => CheckDuplicateMnemonicUsecase(
        secrets: locator<Secrets>(),
        metadata: locator<WalletMetadataDatasource>(),
        settings: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<ImportWalletUsecase>(
      () => ImportWalletUsecase(
        checkDuplicateMnemonicUsecase: locator<CheckDuplicateMnemonicUsecase>(),
        secrets: locator<Secrets>(),
        settingsRepository: locator<SettingsRepository>(),
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerFactory<CheckWalletStatusUsecase>(
      () => CheckWalletStatusUsecase(
        locator<SettingsRepository>(),
        locator<ElectrumServersPort>(),
        locator<BitcoinWalletRepository>(),
        locator<Secrets>(),
      ),
    );
    locator.registerFactory<ScanMnemonicUsecase>(
      () => ScanMnemonicUsecase(
        checkWalletStatus: locator<CheckWalletStatusUsecase>(),
      ),
    );
    registerCubit(locator);
  }

  static void registerCubit(GetIt locator) {
    locator.registerFactory<ImportMnemonicCubit>(
      () => ImportMnemonicCubit(
        importWalletUsecase: locator<ImportWalletUsecase>(),
        scanMnemonicUsecase: locator<ScanMnemonicUsecase>(),
        checkDuplicateMnemonicUsecase: locator<CheckDuplicateMnemonicUsecase>(),
      ),
    );
  }
}
