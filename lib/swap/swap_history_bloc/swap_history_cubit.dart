import 'package:bb_mobile/_model/swap.dart';
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
    final network = _networkCubit.state.getBBNetwork();
    final walletBlocs = _homeCubit.state.walletBlocsFromNetwork(network);
    final swapsToWatch = <(SwapTx, String)>[];
    final uniqueIds = <String>[]; // List to track unique swap IDs

    for (final walletBloc in walletBlocs) {
      final wallet = walletBloc.state.wallet!;
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
    for (final walletBloc in walletBlocs) {
      final wallet = walletBloc.state.wallet!;
      final txs = wallet.transactions.where(
        (_) => _.isSwap && _.swapTx!.close(),
      );
      completedSwaps.addAll(txs);
    }

    // completedSwaps.removeWhere(
    //   (element) => swapsToWatch
    //       .map(
    //         (_) => _.$1.id,
    //       )
    //       .contains(
    //         element.swapTx!.id,
    //       ),
    // );
    // completedSwaps.removeWhere(
    //   (element) => element.swapTx!.close(),
    // );

    emit(state.copyWith(completeSwaps: completedSwaps));

    // migrateHistory();
  }

  // void migrateHistory() async {
  //   // for state.completeswaps
  //   //    - if tx.txid == tx.swaptx.id
  //   //    - if tx.swaptx.txid == null
  //   //      - add to wallet swaps if not there
  //   // if empty return

  //   // save wallet
  //   // loadswaps() and restart watchers

  //   try {
  //     final swapsToAdd = <SwapTx>[];
  //     for (final tx in state.completeSwaps)
  //       if (tx.txid == tx.swapTx!.id || (tx.swapTx!.txid == null)) {
  //         if (!state.checkSwapExists(tx.swapTx!.id)) {
  //           swapsToAdd.add(tx.swapTx!);
  //         }
  //       }

  //     if (swapsToAdd.isEmpty) return;

  //     for (final swap in swapsToAdd) {
  //       final walletBloc = _homeCubit.state.getWalletBlocFromSwapTx(swap);
  //       if (walletBloc == null) continue;
  //       final (updatedWallet, err) = await _walletTx.addSwapTxToWallet(
  //         wallet: walletBloc.state.wallet!,
  //         swapTx: swap,
  //       );
  //       if (err != null) {
  //         print('Error: Adding SwapTx to Wallet: ${swap.id}, Error: $err');
  //         continue;
  //       }

  //       walletBloc.add(
  //         UpdateWallet(
  //           updatedWallet,
  //           updateTypes: [
  //             UpdateWalletTypes.swaps,
  //             UpdateWalletTypes.transactions,
  //           ],
  //         ),
  //       );

  //       await Future.delayed(const Duration(milliseconds: 300));
  //     }

  //     _watcher.add(WatchWallets());

  //     loadSwaps();
  //   } catch (e) {
  //     print('Error: Swap History Processing: $e');
  //   }
  // }

  void swapUpdated(SwapTx swapTx) {
    // print('Swap History Updating: ${swapTx.id} - ${swapTx.status?.status}');
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
    // final updatedSwap = swaptx.copyWith(status: stream);

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
