import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_descriptor_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_xpub_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/parse_watch_only_input_usecase.dart';
import 'package:get_it/get_it.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/validate_watch_only_import_usecase.dart';

class ImportWatchOnlyLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<ValidateWatchOnlyImportUsecase>(
      () => ValidateWatchOnlyImportUsecase(
        settings: locator<SettingsRepository>(),
      ),
    );
    // Use cases
    locator.registerFactory<ParseWatchOnlyInputUsecase>(
      ParseWatchOnlyInputUsecase.new,
    );

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
