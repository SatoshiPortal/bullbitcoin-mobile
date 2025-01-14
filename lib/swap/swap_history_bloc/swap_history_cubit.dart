import 'package:bb_mobile/_model/swap.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_repository/app_wallets_repository.dart';
import 'package:bb_mobile/_repository/network_repository.dart';
import 'package:bb_mobile/swap/swap_history_bloc/swap_history_state.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_event.dart';
import 'package:boltz/boltz.dart' as boltz;
import 'package:flutter_bloc/flutter_bloc.dart';

class SwapHistoryCubit extends Cubit<SwapHistoryState> {
  SwapHistoryCubit({
    required AppWalletsRepository appWalletsRepository,
    required NetworkRepository networkRepository,
    required SwapBoltz boltz,
    required WatchTxsBloc watcher,
  })  : _appWalletsRepository = appWalletsRepository,
        _networkRepository = networkRepository,
        _boltz = boltz,
        _watcher = watcher,
        super(const SwapHistoryState());

  final AppWalletsRepository _appWalletsRepository;
  final NetworkRepository _networkRepository;
  final SwapBoltz _boltz;
  final WatchTxsBloc _watcher;

  void loadSwaps() {
    final network = _networkRepository.getBBNetwork;
    final wallets = _appWalletsRepository.walletsFromNetwork(network);
    final swapsToWatch = <(SwapTx, String)>[];
    final uniqueIds = <String>[];

    for (final wallet in wallets) {
      for (final swap in wallet.swaps) {
        if (!uniqueIds.contains(swap.id)) {
          uniqueIds.add(swap.id);
          swapsToWatch.add((swap, wallet.id));
        }
      }
      for (final tx in wallet.transactions) {
        if (tx.isSwap && !tx.swapTx!.close()) {
          if (!uniqueIds.contains(tx.swapTx!.id)) {
            uniqueIds.add(tx.swapTx!.id);
            swapsToWatch.add((tx.swapTx!, wallet.id));
          }
        }
      }
    }

    emit(state.copyWith(swaps: swapsToWatch));

    final completedSwaps = <Transaction>[];
    for (final wallet in wallets) {
      final txs = wallet.transactions.where(
        (_) => _.isSwap && _.swapTx!.close(),
      );
      completedSwaps.addAll(txs);
    }

    emit(state.copyWith(completeSwaps: completedSwaps));
  }

  void swapUpdated(SwapTx swapTx) {
    emit(state.copyWith(updateSwaps: true));
    final swaps = state.swaps;
    final index = swaps.indexWhere((_) => _.$1.id == swapTx.id);
    if (index == -1) {
      emit(state.copyWith(updateSwaps: false));
      return;
    }

    final updatedSwaps = swaps.toList();
    updatedSwaps[index] = (swapTx, swaps[index].$2);

    emit(
      state.copyWith(
        swaps: updatedSwaps,
        updateSwaps: false,
      ),
    );
  }

  Future<void> refreshSwap({
    required SwapTx swaptx,
    required String walletId,
  }) async {
    final id = swaptx.id;
    if (state.refreshing.contains(id)) return;

    emit(
      state.copyWith(refreshing: [...state.refreshing, id], errRefreshing: ''),
    );

    final (status, err) = await _boltz.getSwapStatus(id, swaptx.isTestnet());
    if (err != null) {
      emit(
        state.copyWith(
          refreshing: state.refreshing.where((_) => _ != id).toList(),
          errRefreshing: 'Error: SwapID: $id, Error: $err',
        ),
      );
      return;
    }

    final stream = boltz.SwapStreamStatus(id: id, status: status!.status);

    _watcher.add(
      ProcessSwapTx(
        walletId: walletId,
        swapTxId: swaptx.id,
        status: stream,
      ),
    );

    emit(
      state.copyWith(
        refreshing: state.refreshing.where((_) => _ != id).toList(),
      ),
    );
  }
}
