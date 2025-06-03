import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/domain/usecases/import_xpub_use_case.dart';
import 'package:bb_mobile/locator.dart';

class ImportWatchOnlyWalletLocator {
  static void setup() {
    // Use cases
    locator.registerFactory<ImportXpubUsecase>(
      () => ImportXpubUsecase(
        settingsRepository: locator<SettingsRepository>(),
        walletRepository: locator<WalletRepository>(),
      ),
    );
  }
}
