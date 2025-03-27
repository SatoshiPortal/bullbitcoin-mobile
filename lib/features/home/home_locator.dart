import 'package:bb_mobile/core/domain/services/wallet_manager_service.dart';
import 'package:bb_mobile/core/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:bb_mobile/locator.dart';

class HomeLocator {
  static void setup() {
    // Bloc
    locator.registerFactory<HomeBloc>(
      () => HomeBloc(
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        walletManagerService: locator<WalletManagerService>(),
      ),
    );
  }
}
