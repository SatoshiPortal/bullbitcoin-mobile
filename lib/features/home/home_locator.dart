import 'package:bb_mobile/app_locator.dart';
import 'package:bb_mobile/core/domain/usecases/get_default_wallets_metadata_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_wallet_balance_sat_usecase.dart';
import 'package:bb_mobile/features/home/presentation/bloc/home_bloc.dart';

class HomeLocator {
  static void setup() {
    // Bloc
    locator.registerFactory<HomeBloc>(
      () => HomeBloc(
        getDefaultWalletsMetadataUseCase:
            locator<GetDefaultWalletsMetadataUseCase>(),
        getWalletBalanceSatUseCase: locator<GetWalletBalanceSatUseCase>(),
      ),
    );
  }
}
