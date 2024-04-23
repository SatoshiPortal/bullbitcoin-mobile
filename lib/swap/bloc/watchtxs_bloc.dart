import 'dart:async';

import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_event.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_state.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 1. WalletBloc.listTxs calls `WatchWalletTxs` for a specific wallet
/// 2. WatchWalletTxs
///   - gets swap txs from wallet given the wallet Id (ISSUE: Sometimes swap txs doesn't return all swaps)
///   - filters swap txs to narrow down only active swaps
///   - For settled swaps, calls
///     - `UpdateOrClaimSwap` (TODO: Why?)
///   - Calls WatchSwapStatus with the narrowed down swap list
/// 3. WatchSwapStatus
///   - combines incoming swap list with 'listeningTxs'
///   - Boltz.addSwapSubs() is called for the combined list
///     (POTENTIAL ISSUE: addSwapSubs should combine the swap list with it's own global swap list, which is a a union of all swap lists from all wallets)
///     - For each WSS update for the given swap list, `SwapStatusUpdate` is called
/// 4. SwapStatusUpdate
///   - This is called for swap status updates from WSS for each listening swaps
///   - For each swap status update, `UpdateOrClaimSwap` is called
/// 5. UpdateOrClaimSwap
///   - If Swap is (reverse and settled) or is (submbarine and status is txnMempool or txnConfirmed | ISSUE: Could also check for txnClaimed. right?),
///     - [Idea] Merge the swap with tx and remove it from wallet.swaps list
///     - Pick swapTx from claimedSwapTxs, if given swap.txid is null (ISSUE: Here swap.txid is null and not found in claimedSwapTxs)
///     - Merge the swap with wallet.tx by calling `walletTransaction.mergeSwapTxIntoTx`
///       - Remove the swap from wallet.swaps since the swap is like DONE now.
///       - Remove swap from secureStorage
///   - If Swap is not claimable
///     - update wallet.swaps[swapTx].txId with right txid and get refund swap list by calling `walletTransaction.updateSwapTxs`
///     - If refund swap list is empty, update wallet with swaps list and return
///   - If swap is claimed
///     - return
///   - In refund scenario, initiate refund and take txid
///   - In claim scenario, initiate claim and take txid
///   - Assign txid to swapTx and and add swap to claimedSwapTxs and update wallet
class WatchTxsBloc extends Bloc<WatchTxsEvent, WatchTxsState> {
  WatchTxsBloc({
    required SwapBoltz swapBoltz,
    required WalletTx walletTx,
    required HomeCubit homeCubit,
  })  : _walletTx = walletTx,
        _homeCubit = homeCubit,
        _swapBoltz = swapBoltz,
        super(const WatchTxsState()) {
    on<InitializeSwapWatcher>(_initializeSwapWatcher);
    on<WatchSwapStatus>(_onWatchSwapStatus);
    on<ProcessSwapTx>(_onProcessSwapTx, transformer: sequential());
    on<SwapStatusUpdate>(_onSwapStatusUpdate);
    on<DeleteSensitiveSwapData>(_onDeleteSensitiveSwapData);
    on<WatchWalletTxs>(_onWatchWalletTxs);
    on<ClearAlerts>(_clearAlerts);
    add(InitializeSwapWatcher());
  }

  final SwapBoltz _swapBoltz;
  final WalletTx _walletTx;

  final HomeCubit _homeCubit;

  void _initializeSwapWatcher(InitializeSwapWatcher event, Emitter<WatchTxsState> emit) async {
    if (state.boltzWatcher != null) return;

    final (boltzWatcher, err) = await _swapBoltz.initializeBoltzApi();
    if (err != null) {
      emit(state.copyWith(errWatchingInvoice: err.message));
      return;
    }
    emit(state.copyWith(boltzWatcher: boltzWatcher));
  }

  void _onWatchWalletTxs(WatchWalletTxs event, Emitter<WatchTxsState> emit) {
    final wallet = event.wallet;

    final swapTxs = wallet.swaps;
    final swapTxsToWatch = <SwapTx>[];

    for (final swapTx in swapTxs) {
      if (swapTx.proceesTx()) {
        add(ProcessSwapTx(walletId: event.wallet.id, swapTx: swapTx));
        continue;
      }
      swapTxsToWatch.add(swapTx);
      print('Listening to Swap: ${swapTx.id}');
    }
    if (swapTxsToWatch.isEmpty) return;
    add(
      WatchSwapStatus(
        swapTxs: swapTxsToWatch.map((_) => _.id).toList(),
        walletId: event.wallet.id,
      ),
    );
  }

  void _onWatchSwapStatus(WatchSwapStatus event, Emitter<WatchTxsState> emit) async {
    if (state.boltzWatcher == null) {
      emit(
        state.copyWith(errWatchingInvoice: 'Watcher not initialized. Re-initializing. Try Again.'),
      );
      add(InitializeSwapWatcher());
      return;
    }

    for (final swap in event.swapTxs) {
      final exists = state.isListening(swap);
      if (exists) continue;
      emit(state.copyWith(listeningTxs: [...state.listeningTxs, swap]));
    }
    final err = await _swapBoltz.addSwapSubs(
      api: state.boltzWatcher!,
      swapIds: event.swapTxs,
      onUpdate: (id, status) {
        add(SwapStatusUpdate(id, status, event.walletId));
      },
    );

    emit(state.copyWith(errWatchingInvoice: err.toString()));
    return;
  }

  void _onSwapStatusUpdate(SwapStatusUpdate event, Emitter<WatchTxsState> emit) async {
    for (final walletBloc in _homeCubit.state.walletBlocs!) {
      if (walletBloc.state.wallet!.hasOngoingSwap(event.swapId)) {
        final id = event.swapId;
        final status = event.status;
        print('SwapStatusUpdate: $id - ${status.status}');
        if (!state.isListeningId(id)) return;
        final swapTx = walletBloc.state.wallet!.getOngoingSwap(id)!.copyWith(status: status);

        final close =
            swapTx.settledReverse() || swapTx.settledSubmarine() || swapTx.expiredReverse();
        if (close) {
          final idx = state.listeningTxs.indexWhere((element) => element == swapTx.id);
          if (idx != -1) {
            final newListeningTxs =
                state.listeningTxs.where((element) => element != swapTx.id).toList();
            emit(state.copyWith(listeningTxs: newListeningTxs));
          }
        }
        add(ProcessSwapTx(walletId: event.walletId, swapTx: swapTx));
      }
    }
  }

  FutureOr<void> _onProcessSwapTx(ProcessSwapTx event, Emitter<WatchTxsState> emit) async {
    final swapTx = event.swapTx;

    final walletBloc = _homeCubit.state.getWalletBlocById(event.walletId);
    final wallet = walletBloc?.state.wallet;
    if (walletBloc == null || wallet == null) return;

    if (swapTx.receiveAction()) __swapAlert(swapTx, wallet, emit);

    if (swapTx.txid != null) {
      await __mergeSwap(wallet, swapTx, walletBloc, emit);
      return;
    }

    final canClaim = swapTx.claimableReverse();
    const shouldRefund = false;
    if (!canClaim) {
      await __updateNoActionSwapTxs(wallet, swapTx, walletBloc, emit);
      return;
    }

    if (state.swapClaimed(swapTx.id) || (state.isClaiming(swapTx.id))) {
      emit(state.copyWith(errClaimingSwap: 'Swap claimed/claiming'));
      return;
    }

    final txid = await __claimOrRefundSwap(shouldRefund, swapTx, walletBloc, emit);
    if (txid == null) return;

    await __updateSwapTxsAfterClaimOrRefund(txid, swapTx, walletBloc, wallet, emit);
  }

  void _onDeleteSensitiveSwapData(
    DeleteSensitiveSwapData event,
    Emitter<WatchTxsState> emit,
  ) async {
    final _ = await _swapBoltz.deleteSwapSensitive(id: event.swapId);
  }

  Future __mergeSwap(
    Wallet wallet,
    SwapTx swapTx,
    WalletBloc walletBloc,
    Emitter<WatchTxsState> emit,
  ) async {
    final (walletAndTxs, err) = await _walletTx.mergeSwapTxIntoTx(
      wallet: wallet,
      swapTx: swapTx,
    );
    if (err != null) {
      emit(state.copyWith(errWatchingInvoice: err.toString()));
      return;
    }
    final updatedWallet = walletAndTxs!.wallet;
    final swapToDelete = walletAndTxs.swapsToDelete;
    walletBloc.add(
      UpdateWallet(
        updatedWallet,
        updateTypes: [UpdateWalletTypes.transactions, UpdateWalletTypes.swaps],
      ),
    );

    add(DeleteSensitiveSwapData(swapToDelete.id));
    add(WatchWalletTxs(wallet: wallet));

    return;
  }

  Future __updateNoActionSwapTxs(
    Wallet wallet,
    SwapTx swapTx,
    WalletBloc walletBloc,
    Emitter<WatchTxsState> emit,
  ) async {
    final (resp, err) = _walletTx.updateSwapTxs(
      wallet: wallet,
      swapTx: swapTx,
    );
    if (err != null) {
      emit(state.copyWith(errWatchingInvoice: err.toString()));
      return;
    }
    final updatedWallet = resp!.wallet;

    walletBloc.add(
      UpdateWallet(
        updatedWallet,
        updateTypes: [UpdateWalletTypes.swaps],
      ),
    );

    Future.delayed(20.ms);
    return;
  }

  Future<String?> __claimOrRefundSwap(
    bool shouldRefund,
    SwapTx swapTx,
    WalletBloc walletBloc,
    Emitter<WatchTxsState> emit,
  ) async {
    final updatedClaimingTxs = state.addClaimingTx(swapTx.id);
    if (updatedClaimingTxs == null) return null;

    emit(
      state.copyWith(
        claimingSwap: true,
        errClaimingSwap: '',
        claimingSwapTxIds: updatedClaimingTxs,
      ),
    );

    await Future.delayed(10.seconds);

    final (txid, err) = await _swapBoltz.claimOrRefundSwap(
      swapTx: swapTx,
      wallet: walletBloc.state.wallet!,
      shouldRefund: shouldRefund,
    );
    if (err != null) {
      emit(
        state.copyWith(
          claimingSwap: false,
          errClaimingSwap: err.toString(),
          claimingSwapTxIds: state.removeClaimingTx(swapTx.id),
        ),
      );
      return null;
    }

    return txid;
  }

  Future __updateSwapTxsAfterClaimOrRefund(
    String txid,
    SwapTx swapTx,
    WalletBloc walletBloc,
    Wallet wallet,
    Emitter<WatchTxsState> emit,
  ) async {
    final updatedSwap = swapTx.copyWith(txid: txid);
    emit(
      state.copyWith(
        claimedSwapTxs: [...state.claimedSwapTxs, updatedSwap.id],
        claimingSwapTxIds: state.removeClaimingTx(updatedSwap.id),
      ),
    );

    final (resp, err1) = _walletTx.updateSwapTxs(swapTx: updatedSwap, wallet: wallet);
    if (err1 != null) {
      emit(state.copyWith(errClaimingSwap: err1.toString()));
      return;
    }

    final updatedWallet = resp!.wallet;

    walletBloc.add(
      UpdateWallet(
        updatedWallet,
        updateTypes: [UpdateWalletTypes.swaps, UpdateWalletTypes.transactions],
      ),
    );
    emit(
      state.copyWith(
        claimingSwap: false,
        errClaimingSwap: '',
      ),
    );
  }

  Future __swapAlert(
    SwapTx swapTx,
    Wallet wallet,
    Emitter<WatchTxsState> emit,
  ) async {
    if (swapTx.paidReverse()) {
      emit(state.copyWith(txPaid: swapTx));
      return;
    }

    if (swapTx.settledReverse()) {
      emit(state.copyWith(syncWallet: wallet));
      return;
    }
  }

  Future<void> _clearAlerts(ClearAlerts event, Emitter<WatchTxsState> emit) async {
    emit(state.copyWith(txPaid: null, syncWallet: null));
  }
}
