import 'package:bb_mobile/core/locator/di_initializer.dart';
import 'package:bb_mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_default_wallets_metadata_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallet_balance_sat_usecase.dart';

void setupHomeDependencies() {
  // Bloc
  locator.registerFactory<HomeBloc>(
    () => HomeBloc(
      getDefaultWalletsMetadataUseCase:
          locator<GetDefaultWalletsMetadataUseCase>(),
      getWalletBalanceSatUseCase: locator<GetWalletBalanceSatUseCase>(),
    ),
  );
}
