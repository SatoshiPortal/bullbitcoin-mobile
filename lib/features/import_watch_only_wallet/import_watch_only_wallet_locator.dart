import 'package:bb_mobile/core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/domain/services/wallet_manager_service.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/usecases/import_xpub_use_case.dart';
import 'package:bb_mobile/locator.dart';

class ImportWatchOnlyWalletLocator {
  static void setup() {
    // Use cases
    locator.registerFactory<ImportXpubUsecase>(
      () => ImportXpubUsecase(
        settingsRepository: locator<SettingsRepository>(),
        walletManagerService: locator<WalletManagerService>(),
      ),
    );
  }
}
