import 'package:bb_mobile/app_locator.dart';
import 'package:bb_mobile/core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/core/domain/services/wallet_metadata_derivator.dart';
import 'package:bb_mobile/core/domain/services/wallet_repository_manager.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/usecases/import_xpub_use_case.dart';

class ImportWatchOnlyWalletLocator {
  static void setup() {
    // Use cases
    locator.registerFactory<ImportXpubUseCase>(
      () => ImportXpubUseCase(
        settingsRepository: locator<SettingsRepository>(),
        walletMetadataDerivator: locator<WalletMetadataDerivator>(),
        walletMetadataRepository: locator<WalletMetadataRepository>(),
        walletRepositoryManager: locator<WalletRepositoryManager>(),
      ),
    );
  }
}
