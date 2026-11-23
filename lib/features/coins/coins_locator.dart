import 'public/coins.dart';

import 'package:bb_mobile/features/coins/data/wallet_utxo_repository_impl.dart';
import 'package:sync/sync.dart' show CoinFreezes;
import 'package:secrets/storage.dart' show SecretsInventory;
import 'package:sync/write.dart' show WalletNativeRuntime;
import 'package:preferences/preferences.dart'
    show AmountDisplayPreferencesReader;
import 'package:bb_mobile/features/coins/domain/usecases/watch_coins_amount_display_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/watch_wallet_revisions_usecase.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/features/coins/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/freeze_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/get_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/refresh_coins_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/unfreeze_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/presentation/coins_cubit.dart';
import 'package:labels/labels.dart';
import 'package:get_it/get_it.dart';
import 'package:bb_mobile/features/coins/domain/usecases/load_coin_label_filters_usecase.dart';

class CoinsLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<Coins>(
      () => Coins(locator<GetUtxosUsecase>().execute),
    );
    locator.registerLazySingleton<WalletUtxoRepository>(
      () => WalletUtxoRepositoryImpl(
        inventory: locator<SecretsInventory>(),
        loadWallet: locator<WalletNativeRuntime>().loadWallet,
        freezesDatasource: locator<CoinFreezes>(),
        labelsFacade: locator<Labels>(),
      ),
    );
    locator.registerLazySingleton<GetWalletUtxosUsecase>(
      () => GetWalletUtxosUsecase(
        utxoRepository: locator<WalletUtxoRepository>(),
      ),
    );
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
    locator.registerFactory<RefreshCoinsUsecase>(
      () => RefreshCoinsUsecase(locator<WalletFacade>()),
    );

    // Cubit — built per route with the target wallet id.
    locator.registerFactoryParam<CoinsCubit, String, void>(
      (walletId, _) => CoinsCubit(
        watchAmountDisplayUsecase: WatchCoinsAmountDisplayUsecase(
          locator<AmountDisplayPreferencesReader>(),
        ),
        watchWalletRevisionsUsecase: WatchWalletRevisionsUsecase(
          locator<WalletNativeRuntime>().changes,
        ),
        walletId: walletId,
        getUtxosUsecase: locator<GetUtxosUsecase>(),
        freezeUtxosUsecase: locator<FreezeUtxosUsecase>(),
        unfreezeUtxosUsecase: locator<UnfreezeUtxosUsecase>(),
        refreshCoinsUsecase: locator<RefreshCoinsUsecase>(),
        loadCoinLabelFilters: LoadCoinLabelFiltersUsecase(locator<Labels>()),
        watchStartedWalletSyncsUsecase:
            locator<WatchStartedWalletSyncsUsecase>(),
        watchFinishedWalletSyncsUsecase:
            locator<WatchFinishedWalletSyncsUsecase>(),
      ),
    );
  }
}
