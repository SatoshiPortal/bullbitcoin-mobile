import 'package:bb_mobile/core/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_any_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:bb_mobile/locator.dart';

class HomeLocator {
  static void setup() {
    // Bloc
    locator.registerFactory<HomeBloc>(
      () => HomeBloc(
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        checkAnyWalletSyncingUsecase: locator<CheckAnyWalletSyncingUsecase>(),
        watchWalletSyncsUsecase: locator<WatchWalletSyncsUsecase>(),
        restartSwapWatcherUsecase: locator<RestartSwapWatcherUsecase>(),
      ),
    );
  }
}
