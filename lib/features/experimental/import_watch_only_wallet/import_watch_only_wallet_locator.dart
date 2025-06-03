import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/domain/usecases/import_watch_only_wallet_usecase.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/extended_public_key_entity.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/presentation/cubit/import_watch_only_cubit.dart';
import 'package:bb_mobile/locator.dart';

class ImportWatchOnlyWalletLocator {
  static void setup() {
    // Use cases
    locator.registerFactory<ImportWatchOnlyWalletUsecase>(
      () => ImportWatchOnlyWalletUsecase(
        settingsRepository: locator<SettingsRepository>(),
        walletRepository: locator<WalletRepository>(),
      ),
    );

    // Cubits
    locator.registerFactory<ImportWatchOnlyCubit>(
      () => ImportWatchOnlyCubit(
        pub: locator<ExtendedPublicKeyEntity>(),
        importWatchOnlyWalletUsecase: locator<ImportWatchOnlyWalletUsecase>(),
      ),
    );
  }
}
