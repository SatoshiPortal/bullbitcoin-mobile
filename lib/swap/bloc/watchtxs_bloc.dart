import 'dart:async';
import 'dart:convert';

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
    required SwapBoltz swapBoltz,
    required WalletTx walletTx,
    required HomeCubit homeCubit,
  })  : _walletTx = walletTx,
        _homeCubit = homeCubit,
        _swapBoltz = swapBoltz,
        super(const WatchTxsState()) {
    on<InitializeSwapWatcher>(_initializeSwapWatcher);
    on<WatchWallets>(_onWatchWallets);
    on<ClearAlerts>(_onClearAlerts);
    // on<WatchSwapStatus>(_onWatchSwapStatus);
    on<ProcessSwapTx>(_onProcessSwapTx, transformer: sequential());
    // on<SwapStatusUpdate>(_onSwapStatusUpdate);
    // on<DeleteSensitiveSwapData>(_onDeleteSensitiveSwapData);

    add(InitializeSwapWatcher());
  }

  final SwapBoltz _swapBoltz;
  final WalletTx _walletTx;

  final HomeCubit _homeCubit;

  BoltzApi? _boltzMainnet;
  BoltzApi? _boltzTestnet;

  late StreamSubscription _mainNetStream;
  late StreamSubscription _testNetStream;

  @override
  Future<void> close() {
    _boltzMainnet = null;
    _boltzTestnet = null;
    _mainNetStream.cancel();
    _testNetStream.cancel();
    return super.close();
  }

  void _initializeSwapWatcher(
    InitializeSwapWatcher event,
    Emitter<WatchTxsState> emit,
  ) async {
    // if (_boltzMainnet != null && _boltzTestnet != null) return;

    // // emit(state.copyWith(isTestnet: event.isTestnet));

    // final (watcher, err) = await _swapBoltz.initializeBoltzApi(false);
    // if (err != null) {
    //   emit(state.copyWith(errWatchingInvoice: err.message));
    //   return;
    // }
    // _boltzMainnet = watcher;

    // final (watcherTestnet, errTestnet) =
    //     await _swapBoltz.initializeBoltzApi(true);
    // if (errTestnet != null) {
    //   emit(state.copyWith(errWatchingInvoice: errTestnet.message));
    //   return;
    // }
    // _boltzTestnet = watcherTestnet;

    // emit(state.copyWith(boltzWatcher: boltzWatcher));

    // await Future.delayed(2.seconds);
    // add(WatchWallets(isTestnet: event.isTestnet));
  }

  void _onWatchWallets(WatchWallets event, Emitter<WatchTxsState> emit) {
    final walletBlocs = _homeCubit.state.getMainWallets(event.isTestnet);
    final swapsToWatch = <SwapTx>[];
    for (final walletBloc in walletBlocs) {
      final wallet = walletBloc.state.wallet!;
      for (final swapTx in wallet.swapsToProcess())
        add(ProcessSwapTx(walletId: wallet.id, swapTx: swapTx));
      swapsToWatch.addAll(wallet.swaps);
    }
    swapsToWatch.removeWhere((_) => _.failed());
    if (swapsToWatch.isEmpty) return;
    print('Listening to Swaps: ${swapsToWatch.map((_) => _.id).toList()}');
    __watchSwapStatus(
      emit,
      swapTxsToWatch: swapsToWatch.map((_) => _.id).toList(),
      isTestnet: event.isTestnet,
    );
  }

  Future<void> _onClearAlerts(
    ClearAlerts event,
    Emitter<WatchTxsState> emit,
  ) async {
    emit(state.copyWith(txPaid: null, syncWallet: null));
  }

  void __watchSwapStatus(
    Emitter<WatchTxsState> emit, {
    // required String walletId,
    required List<String> swapTxsToWatch,
    required bool isTestnet,
  }) async {
    if (swapTxsToWatch.isEmpty) return;
    if (_boltzMainnet == null && _boltzTestnet == null) {
      emit(
        state.copyWith(
          errWatchingInvoice:
              'Watcher not initialized. Re-initializing. Try Again.',
        ),
      );

      // add(InitializeSwapWatcher());
      return;
    }

    for (final swap in swapTxsToWatch) {
      final exists = state.isListening(swap);
      if (exists) continue;
      emit(state.copyWith(listeningTxs: [...state.listeningTxs, swap]));
    }
    if (isTestnet) {
      _testNetStream =
          _boltzTestnet!.subscribeSwapStatus(swapTxsToWatch).listen(
        (event) {
          __swapStatusUpdated(
            emit,
            swapId: event.id,
            status: event,
          );
        },
      );
    } else {
      _mainNetStream =
          _boltzMainnet!.subscribeSwapStatus(swapTxsToWatch).listen(
        (event) {
          __swapStatusUpdated(
            emit,
            swapId: event.id,
            status: event,
          );
        },
      );
    }

    // final err = await _swapBoltz.addSwapSubs(
    //   api: isTestnet ? _boltzTestnet! : _boltzMainnet!,
    //   swapIds: swapTxsToWatch,
    //   onUpdate: (id, status) {
    //     print('SwapStatusUpdatedd: $id - ${status.status}');
    //     __swapStatusUpdated(
    //       emit,
    //       swapId: id,
    //       status: status,
    //       // walletId: walletId,
    //     );
    //   },
    // );
    // if (err != null) emit(state.copyWith(errWatchingInvoice: err.toString()));
  }

  void __swapStatusUpdated(
    Emitter<WatchTxsState> emit, {
    required String swapId,
    required SwapStreamStatus status,
    // required String walletId,
  }) async {
    for (final walletBloc in _homeCubit.state.walletBlocs!) {
      if (walletBloc.state.wallet!.hasOngoingSwap(swapId)) {
        final id = swapId;
        print('SwapStatusUpdate: $id - ${status.status}');
        if (!state.isListeningId(id)) return;
        final swapTx = walletBloc.state.wallet!
            .getOngoingSwap(id)!
            .copyWith(status: status);

        add(
          ProcessSwapTx(
            walletId: walletBloc.state.wallet!.id,
            swapTx: swapTx,
          ),
        );
      }
    }
  }

  // void __deleteSensitiveSwapData(
  //   String swapId,
  //   Emitter<WatchTxsState> emit,
  // ) async {
  //   final _ = await _swapBoltz.deleteSwapSensitive(id: swapId);
  // }

  // Future<Err?> __mergeSwapIfTxExists(
  //   Wallet w,
  //   SwapTx swapTx,
  //   Emitter<WatchTxsState> emit,
  // ) async {
  //   await Future.delayed(200.ms);

  //   final walletBloc = _homeCubit.state.getWalletBlocById(w.id);
  //   final wallet = walletBloc?.state.wallet;
  //   if (walletBloc == null || wallet == null) return Err('Wallet not found');

  //   final (walletAndTxs, err) = await _walletTx.mergeSwapTxIntoTx(
  //     wallet: wallet,
  //     swapTx: swapTx,
  //   );
  //   if (err != null) {
  //     emit(
  //       state.copyWith(
  //         errWatchingInvoice: err.toString(),
  //       ),
  //     );

  //     return err;
  //   }
  //   final updatedWallet = walletAndTxs!.wallet;
  //   final swapToDelete = walletAndTxs.swapsToDelete;
  //   walletBloc.add(
  //     UpdateWallet(
  //       updatedWallet,
  //       updateTypes: [
  //         UpdateWalletTypes.transactions,
  //         UpdateWalletTypes.swaps,
  //       ],
  //     ),
  //   );

  //   final errDelete = await _swapBoltz.deleteSwapSensitive(id: swapToDelete.id);
  //   if (errDelete != null) {
  //     emit(state.copyWith(errWatchingInvoice: errDelete.toString()));
  //     return null;
  //   }

  //   Future.delayed(500.ms);

  //   emit(state.copyWith(syncWallet: updatedWallet));

  //   Future.delayed(200.ms);

  //   // _homeCubit.updateWalletBloc(walletBloc);
  //   // _homeCubit.getWalletsFromStorage();

  //   return null;
  // }

  Future<Wallet?> __updateWalletTxs(
    // Wallet wallet,
    SwapTx swapTx,
    WalletBloc walletBloc,
    Emitter<WatchTxsState> emit,
  ) async {
    final (resp, err) = _walletTx.updateSwapTxs(
      wallet: walletBloc.state.wallet!,
      swapTx: swapTx,
    );
    if (err != null) {
      emit(state.copyWith(errWatchingInvoice: err.toString()));
      return null;
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

    Future.delayed(200.ms);
    return updatedWallet;
  }

  Future<SwapTx?> __claimOrRefundSwap(
    SwapTx swapTx,
    WalletBloc walletBloc,
    Emitter<WatchTxsState> emit, {
    bool shouldRefund = false,
  }) async {
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
      print(err);
      emit(
        state.copyWith(
          claimingSwap: false,
          errClaimingSwap: err.toString(),
          claimingSwapTxIds: state.removeClaimingTx(swapTx.id),
        ),
      );
      return null;
    }

    SwapTx updatedSwap;
    try {
      final json = jsonDecode(txid!) as Map<String, dynamic>;
      updatedSwap = swapTx.copyWith(txid: json['id'] as String);
    } catch (e) {
      updatedSwap = swapTx.copyWith(txid: txid);
    }

    emit(
      state.copyWith(
        claimedSwapTxs: [...state.claimedSwapTxs, updatedSwap.id],
        claimingSwapTxIds: state.removeClaimingTx(updatedSwap.id),
        claimingSwap: false,
        syncWallet: walletBloc.state.wallet,
      ),
    );

    return updatedSwap;
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

  Future __closeSwap(
    SwapTx swapTx,
    Emitter<WatchTxsState> emit,
  ) async {
    emit(
      state.copyWith(listeningTxs: state.removeListeningTx(swapTx.id)),
    );
    await Future.delayed(1000.ms);
    final isTestnet = swapTx.network == BBNetwork.Testnet;
    add(WatchWallets(isTestnet: isTestnet));
  }

  Future<void> _onProcessSwapTx(
    ProcessSwapTx event,
    Emitter<WatchTxsState> emit,
  ) async {
    await Future.delayed(1.seconds);
    final swapTx = event.swapTx;
    final walletBloc = _homeCubit.state.getWalletBlocById(event.walletId);
    final wallet = walletBloc?.state.wallet;
    if (walletBloc == null || wallet == null) return;

    if (!swapTx.isSubmarine)
      switch (swapTx.reverseSwapAction()) {
        case ReverseSwapActions.created:
          await __updateWalletTxs(swapTx, walletBloc, emit);
        case ReverseSwapActions.failed:
          await __updateWalletTxs(swapTx, walletBloc, emit);
          await __closeSwap(swapTx, emit);

        case ReverseSwapActions.claimable:
          __swapAlert(swapTx, wallet, emit);
          final swap = await __claimOrRefundSwap(swapTx, walletBloc, emit);
          if (swap != null) await __updateWalletTxs(swap, walletBloc, emit);
        case ReverseSwapActions.settled:
          __swapAlert(swapTx, wallet, emit);
          final w = await __updateWalletTxs(swapTx, walletBloc, emit);
          if (w == null) return;
          // final err = await __mergeSwapIfTxExists(w, swapTx, emit);
          await __closeSwap(swapTx, emit);
      }
  }
}















  // case swapTx.close():
    //   break;
    // swaclaimableReverse()=>{},
    // _ => {},

    // if (swapTx.receiveAction()) __swapAlert(swapTx, wallet, emit);

    // if (swapTx.txid != null) {
    //   await __mergeSwap(wallet, swapTx, walletBloc, emit);
    //   return;
    // }

    // if (swapTx.close()) {
    //   await __updateWalletTxs(wallet, swapTx, walletBloc, emit);
    //   await __closeSwap(emit, swapTx: swapTx);
    //   return;
    // }

    // final canClaim = swapTx.claimableReverse();
    // const shouldRefund = false;
    // if (!canClaim) {
    //   await __updateWalletTxs(wallet, swapTx, walletBloc, emit);
    //   return;
    // }

    // final txid =
    //     await __claimOrRefundSwap(shouldRefund, swapTx, walletBloc, emit);
    // if (txid == null) return;

    // final updatedSwap = swapTx.copyWith(txid: txid);

    // emit(
    //   state.copyWith(
    //     claimedSwapTxs: [...state.claimedSwapTxs, updatedSwap.id],
    //     claimingSwapTxIds: state.removeClaimingTx(updatedSwap.id),
    //   ),
    // );

    // await __updateWalletTxs(wallet, swapTx, walletBloc, emit);
