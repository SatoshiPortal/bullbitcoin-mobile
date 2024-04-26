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
import 'package:boltz_dart/boltz_dart.dart';
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
    required bool isTestnet,
    required SwapBoltz swapBoltz,
    required WalletTx walletTx,
    required HomeCubit homeCubit,
  })  : _walletTx = walletTx,
        _homeCubit = homeCubit,
        _swapBoltz = swapBoltz,
        super(WatchTxsState(isTestnet: isTestnet)) {
    on<InitializeSwapWatcher>(_initializeSwapWatcher);
    on<WatchWalletTxs>(_onWatchWalletTxs);
    on<ClearAlerts>(_onClearAlerts);
    // on<WatchSwapStatus>(_onWatchSwapStatus);
    on<ProcessSwapTx>(_onProcessSwapTx, transformer: sequential());
    // on<SwapStatusUpdate>(_onSwapStatusUpdate);
    // on<DeleteSensitiveSwapData>(_onDeleteSensitiveSwapData);

    add(InitializeSwapWatcher(isTestnet: isTestnet));
  }

  final SwapBoltz _swapBoltz;
  final WalletTx _walletTx;

  final HomeCubit _homeCubit;

  void _initializeSwapWatcher(
    InitializeSwapWatcher event,
    Emitter<WatchTxsState> emit,
  ) async {
    if (state.boltzWatcher != null) return;

    final (boltzWatcher, err) =
        await _swapBoltz.initializeBoltzApi(event.isTestnet);
    if (err != null) {
      emit(state.copyWith(errWatchingInvoice: err.message));
      return;
    }
    emit(state.copyWith(boltzWatcher: boltzWatcher));
  }

  void _onWatchWalletTxs(WatchWalletTxs event, Emitter<WatchTxsState> emit) {
    final wallet = event.wallet;

    final swapTxs = wallet.swaps;
    final swapsToProcess = wallet.swapsToProcess();

    for (final swapTx in swapsToProcess)
      add(ProcessSwapTx(walletId: event.wallet.id, swapTx: swapTx));

    if (swapTxs.isEmpty) return;

    __watchSwapStatus(
      emit,
      swapTxsToWatch: swapTxs.map((_) => _.id).toList(),
      walletId: event.wallet.id,
    );
  }

  Future<void> _onClearAlerts(
    ClearAlerts event,
    Emitter<WatchTxsState> emit,
  ) async {
    emit(state.copyWith(txPaid: null, syncWallet: null));
  }

  Future<void> _onProcessSwapTx(
    ProcessSwapTx event,
    Emitter<WatchTxsState> emit,
  ) async {
    final walletId = event.walletId;
    final swapTx = event.swapTx;

    final walletBloc = _homeCubit.state.getWalletBlocById(walletId);
    final wallet = walletBloc?.state.wallet;
    if (walletBloc == null || wallet == null) return;

    if (swapTx.receiveAction()) __swapAlert(swapTx, wallet, emit);

    if (swapTx.txid != null) {
      await __mergeSwap(wallet, swapTx, walletBloc, emit);
      return;
    }

    if (swapTx.close()) {
      emit(
        state.copyWith(listeningTxs: state.removeListeningTx(swapTx.id)),
      );
      await __updateSwapTxs(wallet, swapTx, walletBloc, emit);
      return;
    }

    final canClaim = swapTx.claimableReverse();
    const shouldRefund = false;
    if (!canClaim) {
      await __updateSwapTxs(wallet, swapTx, walletBloc, emit);
      return;
    }

    final txid =
        await __claimOrRefundSwap(shouldRefund, swapTx, walletBloc, emit);
    if (txid == null) return;

    await __updateSwapTxsAfterClaimOrRefund(
      txid,
      swapTx,
      walletBloc,
      wallet,
      emit,
    );
  }

  void __watchSwapStatus(
    Emitter<WatchTxsState> emit, {
    required String walletId,
    required List<String> swapTxsToWatch,
  }) async {
    if (state.boltzWatcher == null) {
      emit(
        state.copyWith(
          errWatchingInvoice:
              'Watcher not initialized. Re-initializing. Try Again.',
        ),
      );

      add(InitializeSwapWatcher(isTestnet: state.isTestnet));
      return;
    }

    for (final swap in swapTxsToWatch) {
      final exists = state.isListening(swap);
      if (exists) continue;
      emit(state.copyWith(listeningTxs: [...state.listeningTxs, swap]));
    }
    final err = await _swapBoltz.addSwapSubs(
      api: state.boltzWatcher!,
      swapIds: swapTxsToWatch,
      onUpdate: (id, status) {
        __swapStatusUpdated(
          emit,
          swapId: id,
          status: status,
          walletId: walletId,
        );
      },
    );
    if (err != null) emit(state.copyWith(errWatchingInvoice: err.toString()));
  }

  void __swapStatusUpdated(
    Emitter<WatchTxsState> emit, {
    required String swapId,
    required SwapStatusResponse status,
    required String walletId,
  }) async {
    for (final walletBloc in _homeCubit.state.walletBlocs!) {
      if (walletBloc.state.wallet!.hasOngoingSwap(swapId)) {
        final id = swapId;
        print('SwapStatusUpdate: $id - ${status.status}');
        if (!state.isListeningId(id)) return;
        final swapTx = walletBloc.state.wallet!
            .getOngoingSwap(id)!
            .copyWith(status: status);

        add(ProcessSwapTx(walletId: walletId, swapTx: swapTx));
      }
    }
  }

  void __deleteSensitiveSwapData(
    String swapId,
    Emitter<WatchTxsState> emit,
  ) async {
    final _ = await _swapBoltz.deleteSwapSensitive(id: swapId);
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

    __deleteSensitiveSwapData(swapToDelete.id, emit);
    // add(WatchWalletTxs(wallet: wallet));

    return;
  }

  Future __updateSwapTxs(
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
    if (state.swapClaimed(swapTx.id) || (state.isClaiming(swapTx.id))) {
      emit(state.copyWith(errClaimingSwap: 'Swap claimed/claiming'));
      return null;
    }

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

    final (resp, err1) =
        _walletTx.updateSwapTxs(swapTx: updatedSwap, wallet: wallet);
    if (err1 != null) {
      emit(state.copyWith(errClaimingSwap: err1.toString()));
      return;
    }

    final updatedWallet = resp!.wallet;

    walletBloc.add(
      UpdateWallet(
        updatedWallet,
        updateTypes: [
          UpdateWalletTypes.swaps,
          UpdateWalletTypes.transactions,
        ],
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
      emit(state.copyWith(syncWallet: wallet, txPaid: swapTx));
      return;
    }
  }
}
