import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/freeze_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/get_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/unfreeze_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/presentation/coins_cubit.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:get_it/get_it.dart';

class CoinsLocator {
  static void setup(GetIt locator) {
    // Feature usecases (thin wrappers over the shared core wallet layer).
    locator.registerFactory<GetUtxosUsecase>(
      () => GetUtxosUsecase(
        getWalletUtxosUsecase: locator<GetWalletUtxosUsecase>(),
      ),
    );
    locator.registerFactory<FreezeUtxosUsecase>(
      () => FreezeUtxosUsecase(
        walletUtxoRepository: locator<WalletUtxoRepository>(),
      ),
    );
    locator.registerFactory<UnfreezeUtxosUsecase>(
      () => UnfreezeUtxosUsecase(
        walletUtxoRepository: locator<WalletUtxoRepository>(),
      ),
    );

    // Cubit — built per route with the target wallet id.
    locator.registerFactoryParam<CoinsCubit, String, void>(
      (walletId, _) => CoinsCubit(
        walletId: walletId,
        getUtxosUsecase: locator<GetUtxosUsecase>(),
        freezeUtxosUsecase: locator<FreezeUtxosUsecase>(),
        unfreezeUtxosUsecase: locator<UnfreezeUtxosUsecase>(),
        labelsFacade: locator<LabelsFacade>(),
        watchStartedWalletSyncsUsecase:
            locator<WatchStartedWalletSyncsUsecase>(),
        watchFinishedWalletSyncsUsecase:
            locator<WatchFinishedWalletSyncsUsecase>(),
      ),
    );
  }
}
