import 'package:bb_mobile/core/wallet/domain/usecases/get_balance_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/sync_all_wallets_usecase.dart';
import 'package:bb_mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:bb_mobile/locator.dart';

class HomeLocator {
  static void setup() {
    // Bloc
    locator.registerFactory<HomeBloc>(
      () => HomeBloc(
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        syncAllWalletsUsecase: locator<SyncAllWalletsUsecase>(),
        getBalanceUsecase: locator<GetBalanceUsecase>(),
      ),
    );
  }
}
