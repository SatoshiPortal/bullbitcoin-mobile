import 'package:bb_mobile/core/locator/di_initializer.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/fetch_all_wallets_metadata_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/init_wallets_usecase.dart';

void setupAppStartupDependencies() {
  // Bloc
  locator.registerFactory<AppStartupBloc>(
    () => AppStartupBloc(
      fetchAllWalletsMetadataUseCase: locator<FetchAllWalletsMetadataUseCase>(),
      initWalletsUseCase: locator<InitWalletsUseCase>(),
    ),
  );
}
