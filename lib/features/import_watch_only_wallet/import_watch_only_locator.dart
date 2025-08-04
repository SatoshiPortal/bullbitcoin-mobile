import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_descriptor_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_xpub_usecase.dart';
import 'package:bb_mobile/locator.dart';

class ImportWatchOnlyLocator {
  static void setup() {
    // Use cases
    locator.registerFactory<ImportWatchOnlyDescriptorUsecase>(
      () => ImportWatchOnlyDescriptorUsecase(
        walletRepository: locator<WalletRepository>(),
      ),
    );

    locator.registerFactory<ImportWatchOnlyXpubUsecase>(
      () => ImportWatchOnlyXpubUsecase(
        walletRepository: locator<WalletRepository>(),
      ),
    );
  }
}
