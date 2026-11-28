import 'package:go_router/go_router.dart';
import 'package:labels/labels.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show WalletInventory;
import 'package:sync/sync.dart';

import '../coins.dart';
import 'data/wallet_utxo_repository_impl.dart';
import 'domain/repositories/wallet_utxo_repository.dart';
import 'domain/usecases/freeze_utxos_usecase.dart';
import 'domain/usecases/get_utxos_usecase.dart';
import 'domain/usecases/load_coin_label_filters_usecase.dart';
import 'domain/usecases/refresh_coins_usecase.dart';
import 'domain/usecases/unfreeze_utxos_usecase.dart';
import 'domain/usecases/watch_coins_amount_display_usecase.dart';
import 'domain/usecases/watch_wallet_revisions_usecase.dart';
import 'presentation/coins_cubit.dart';
import 'ui/coins_router.dart';

final class CoinsFeature {
  final Coins coins;
  final GoRoute route;

  const CoinsFeature._(this.coins, this.route);

  static CoinsFeature mount<T extends Object>({
    required WalletInventory inventory,
    required Future<Result<Wallet, SyncFailure>> Function(WalletKey) loadWallet,
    required Future<Result<Set<Outpoint>, SyncFailure>> Function()
    readFrozenOutpoints,
    required Future<Result<void, SyncFailure>> Function(
      WalletKey,
      List<Outpoint>,
    )
    freezeWalletOutpoints,
    required Future<Result<void, SyncFailure>> Function(List<Outpoint>)
    unfreezeOutpoints,
    required Labels labels,
    required AmountDisplayPreferencesReader preferences,
    required Future<void> Function(String) poll,
    required Stream<String> Function(String) watchRevisions,
    required Stream<String> Function(String) watchStartedSyncs,
    required Stream<String> Function(String) watchFinishedSyncs,
    required String Function(T) walletId,
    required String missingWalletRedirect,
    required OpenSelectedCoinsFlow<T> onSend,
    required OpenSelectedCoinsFlow<T> onSweep,
  }) {
    final repository = WalletUtxoRepositoryImpl(
      inventory: inventory,
      loadWallet: loadWallet,
      readFrozenOutpoints: readFrozenOutpoints,
      freezeWalletOutpoints: freezeWalletOutpoints,
      unfreezeOutpoints: unfreezeOutpoints,
      labelsFacade: labels,
    );
    final load = GetUtxosUsecase(repository: repository);
    return CoinsFeature._(
      _Coins(load, repository),
      coinsRoute<T>(
        walletId: walletId,
        missingWalletRedirect: missingWalletRedirect,
        onSend: onSend,
        onSweep: onSweep,
        createCubit: (id) => CoinsCubit(
          walletId: id,
          getUtxosUsecase: load,
          freezeUtxosUsecase: FreezeUtxosUsecase(
            walletUtxoRepository: repository,
          ),
          unfreezeUtxosUsecase: UnfreezeUtxosUsecase(
            walletUtxoRepository: repository,
          ),
          refreshCoinsUsecase: RefreshCoinsUsecase(poll),
          loadCoinLabelFilters: LoadCoinLabelFiltersUsecase(labels),
          watchAmountDisplayUsecase: WatchCoinsAmountDisplayUsecase(
            preferences,
          ),
          watchWalletRevisionsUsecase: WatchWalletRevisionsUsecase(
            (walletId) => watchRevisions(walletId ?? id),
          ),
          startedSyncs: watchStartedSyncs(id),
          finishedSyncs: watchFinishedSyncs(id),
        ),
      ),
    );
  }
}

final class _Coins implements Coins {
  final GetUtxosUsecase _load;
  final WalletUtxoRepository _repository;

  const _Coins(this._load, this._repository);

  @override
  Future<Result<List<WalletUtxo>, CoinsFailure>> load({
    required String walletId,
  }) => _load.execute(walletId: walletId);

  @override
  Future<Result<CoinSummary, CoinsFailure>> summary(String walletId) async =>
      (await load(walletId: walletId)).map(
        (utxos) => (
          count: utxos.length,
          frozenSat: utxos
              .where((utxo) => utxo.isFrozen)
              .fold(BigInt.zero, (sum, utxo) => sum + utxo.amountSat),
        ),
      );

  @override
  Future<Result<List<Outpoint>, CoinsFailure>> frozenOutpoints() =>
      _repository.getAllFrozenOutpoints();
}
