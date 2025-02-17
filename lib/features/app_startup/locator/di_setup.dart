import 'package:bb_mobile/core/locator/di_initializer.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/init_wallets_usecase.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/wallet/domain/services/wallet_repository_manager.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/fetch_usable_wallets_metadata_usecase.dart';

void setupAppStartupDependencies() {
  locator.registerFactory<InitWalletsUseCase>(
    () => InitWalletsUseCase(
      walletManager: locator<WalletRepositoryManager>(),
    ),
  );
  // Bloc
  locator.registerFactory<AppStartupBloc>(
    () => AppStartupBloc(
      fetchAllWalletsMetadataUseCase:
          locator<FetchUsableWalletsMetadataUseCase>(),
      initWalletsUseCase: locator<InitWalletsUseCase>(),
    ),
  );
}
