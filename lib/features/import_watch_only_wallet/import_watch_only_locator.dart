import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_compact_block_filters_available_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/resolve_wallet_birthday_checkpoint_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_descriptor_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_xpub_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/parse_watch_only_input_usecase.dart';
import 'package:get_it/get_it.dart';

class ImportWatchOnlyLocator {
  static void setup(GetIt locator) {
    // Use cases
    locator.registerFactory<ParseWatchOnlyInputUsecase>(
      ParseWatchOnlyInputUsecase.new,
    );

    locator.registerFactory<ImportWatchOnlyDescriptorUsecase>(
      () => ImportWatchOnlyDescriptorUsecase(
        walletRepository: locator<WalletRepository>(),
        settingsRepository: locator<SettingsRepository>(),
        checkCompactBlockFiltersAvailableUsecase:
            locator<CheckCompactBlockFiltersAvailableUsecase>(),
        resolveWalletBirthdayCheckpointUsecase:
            locator<ResolveWalletBirthdayCheckpointUsecase>(),
      ),
    );

    locator.registerFactory<ImportWatchOnlyXpubUsecase>(
      () => ImportWatchOnlyXpubUsecase(
        walletRepository: locator<WalletRepository>(),
        settingsRepository: locator<SettingsRepository>(),
        checkCompactBlockFiltersAvailableUsecase:
            locator<CheckCompactBlockFiltersAvailableUsecase>(),
        resolveWalletBirthdayCheckpointUsecase:
            locator<ResolveWalletBirthdayCheckpointUsecase>(),
      ),
    );
  }
}
