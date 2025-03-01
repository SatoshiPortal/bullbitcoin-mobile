import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager.dart';
import 'package:bb_mobile/import_watch_only_wallet/domain/usecases/import_xpub_use_case.dart';
import 'package:bb_mobile/locator.dart';

class ImportWatchOnlyWalletLocator {
  static void setup() {
    // Use cases
    locator.registerFactory<ImportXpubUseCase>(
      () => ImportXpubUseCase(
        settingsRepository: locator<SettingsRepository>(),
        walletManager: locator<WalletManager>(),
      ),
    );
  }
}
