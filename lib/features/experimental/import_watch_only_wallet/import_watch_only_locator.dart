import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/import_watch_only_usecase.dart';
import 'package:bb_mobile/locator.dart';

class ImportWatchOnlyLocator {
  static void setup() {
    // Use cases
    locator.registerFactory<ImportWatchOnlyUsecase>(
      () =>
          ImportWatchOnlyUsecase(walletRepository: locator<WalletRepository>()),
    );
  }
}
