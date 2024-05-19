import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/swap/swap_history_bloc/swap_history_state.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_event.dart';
import 'package:boltz_dart/boltz_dart.dart' as boltz;
import 'package:flutter_bloc/flutter_bloc.dart';

class SwapHistoryCubit extends Cubit<SwapHistoryState> {
  SwapHistoryCubit({
    required HomeCubit homeCubit,
    required NetworkCubit networkCubit,
    required SwapBoltz boltz,
    required WatchTxsBloc watcher,
  })  : _homeCubit = homeCubit,
        _networkCubit = networkCubit,
        _boltz = boltz,
        _watcher = watcher,
        super(const SwapHistoryState());

  final HomeCubit _homeCubit;
  final NetworkCubit _networkCubit;
  final SwapBoltz _boltz;
  final WatchTxsBloc _watcher;

  void loadSwaps() {
    final isTestnet = _networkCubit.state.testnet;
    final walletBlocs = _homeCubit.state.getMainWallets(isTestnet);
    final swapsToWatch = <SwapTx>[];
    for (final walletBloc in walletBlocs) {
      final wallet = walletBloc.state.wallet!;
      swapsToWatch.addAll(wallet.swaps);
    }
    emit(state.copyWith(swaps: swapsToWatch));

    final completedSwaps = <Transaction>[];
    for (final walletBloc in walletBlocs) {
      final wallet = walletBloc.state.wallet!;
      final txs = wallet.transactions.where(
        (_) => _.swapTx != null,
      );
      completedSwaps.addAll(txs);
    }

    completedSwaps.removeWhere(
      (element) => swapsToWatch.map((_) => _.id).contains(element.swapTx!.id),
    );

    emit(state.copyWith(completeSwaps: completedSwaps));
  }

  void refreshSwap({
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
          errRefreshing: 'Error: SwapID: $id, Error: ' + err.toString(),
        ),
      );
      return;
    }

    final stream = boltz.SwapStreamStatus(id: id, status: status!.status);
    final updatedSwap = swaptx.copyWith(status: stream);

    _watcher.add(ProcessSwapTx(walletId: walletId, swapTx: updatedSwap));

    emit(
      state.copyWith(
        refreshing: state.refreshing.where((_) => _ != id).toList(),
      ),
    );
  }
}
