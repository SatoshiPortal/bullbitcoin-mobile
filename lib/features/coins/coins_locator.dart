import 'package:coins/coins.dart';

import 'package:sync/sync.dart' show CoinFreezes, WalletKey;
import 'package:secrets/storage.dart' show SecretsInventory;
import 'package:sync/write.dart' show ElectrumSync, WalletNativeRuntime;
import 'package:preferences/preferences.dart'
    show AmountDisplayPreferencesReader;
import 'package:bb_mobile/features/coins/domain/usecases/watch_coins_amount_display_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/watch_coins_activity_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/freeze_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/get_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/refresh_coins_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/unfreeze_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/presentation/coins_cubit.dart';
import 'package:labels/labels.dart';
import 'package:get_it/get_it.dart';
import 'package:bb_mobile/features/coins/domain/usecases/load_coin_label_filters_usecase.dart';

class CoinsLocator {
  static void setup(
    GetIt locator, {
    required Future<void> Function(String) pollWallet,
  }) {
    locator.registerLazySingleton<Coins>(
      () => Coins.open(
        inventory: locator<SecretsInventory>(),
        loadWallet: locator<WalletNativeRuntime>().loadWallet,
        freezes: locator<CoinFreezes>(),
        labels: locator<Labels>(),
      ),
    );
    locator.registerFactory<GetUtxosUsecase>(
      () => GetUtxosUsecase(locator<Coins>()),
    );
    locator.registerFactory<FreezeUtxosUsecase>(
      () => FreezeUtxosUsecase(locator<Coins>()),
    );
    locator.registerFactory<UnfreezeUtxosUsecase>(
      () => UnfreezeUtxosUsecase(locator<Coins>()),
    );
    locator.registerFactory<RefreshCoinsUsecase>(
      () => RefreshCoinsUsecase(pollWallet),
    );

    // Cubit — built per route with the target wallet id.
    locator.registerFactoryParam<CoinsCubit, WalletKey, void>(
      (key, _) => CoinsCubit(
        watchAmountDisplayUsecase: WatchCoinsAmountDisplayUsecase(
          locator<AmountDisplayPreferencesReader>(),
        ),
        watchActivity: WatchCoinsActivityUsecase(
          locator<ElectrumSync>().started,
          locator<ElectrumSync>().finished.map((event) => event.key),
          locator<WalletNativeRuntime>().changes,
        ),
        walletKey: key,
        getUtxosUsecase: locator<GetUtxosUsecase>(),
        freezeUtxosUsecase: locator<FreezeUtxosUsecase>(),
        unfreezeUtxosUsecase: locator<UnfreezeUtxosUsecase>(),
        refreshCoinsUsecase: locator<RefreshCoinsUsecase>(),
        loadCoinLabelFilters: LoadCoinLabelFiltersUsecase(locator<Labels>()),
      ),
    );
  }
}
