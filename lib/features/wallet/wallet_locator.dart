import 'package:bb_mobile/core/electrum/domain/usecases/get_prioritized_server_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/core/tor/domain/usecases/check_for_tor_initialization_usecase.dart';
import 'package:bb_mobile/core/tor/domain/usecases/initialize_tor_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/wallet/presentation/blocs/detail/wallet_detail_bloc.dart';
import 'package:bb_mobile/features/wallet/presentation/blocs/home/wallet_home_bloc.dart';
import 'package:bb_mobile/locator.dart';

class WalletLocator {
  static void setup() {
    // Bloc
    locator.registerFactory<WalletHomeBloc>(
      () => WalletHomeBloc(
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        checkWalletSyncingUsecase: locator<CheckWalletSyncingUsecase>(),
        watchStartedWalletSyncsUsecase:
            locator<WatchStartedWalletSyncsUsecase>(),
        watchFinishedWalletSyncsUsecase:
            locator<WatchFinishedWalletSyncsUsecase>(),
        restartSwapWatcherUsecase: locator<RestartSwapWatcherUsecase>(),
        initializeTorUsecase: locator<InitializeTorUsecase>(),
        checkForTorInitializationOnStartupUsecase:
            locator<CheckTorRequiredOnStartupUsecase>(),
        getBestAvailableServerUsecase: locator<GetPrioritizedServerUsecase>(),
      ),
    );

    locator.registerFactoryParam<WalletDetailBloc, String, void>(
      (walletId, _) => WalletDetailBloc(
        walletId: walletId,
        getWalletUsecase: locator<GetWalletUsecase>(),
      ),
    );
  }
}
