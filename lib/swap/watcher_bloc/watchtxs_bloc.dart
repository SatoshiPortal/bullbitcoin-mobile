import 'dart:async';
import 'dart:convert';

import 'package:bb_mobile/_model/network.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_event.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_state.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:boltz_dart/boltz_dart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WatchTxsBloc extends Bloc<WatchTxsEvent, WatchTxsState> {
  WatchTxsBloc({
    required SwapBoltz swapBoltz,
    required WalletTx walletTx,
    required HomeCubit homeCubit,
    required NetworkCubit networkCubit,
  })  : _walletTx = walletTx,
        _homeCubit = homeCubit,
        _networkCubit = networkCubit,
        _swapBoltz = swapBoltz,
        super(const WatchTxsState()) {
    on<WatchWallets>(_onWatchWallets);
    // on<ClearAlerts>(_onClearAlerts);
    on<ProcessSwapTx>(_onProcessSwapTx, transformer: sequential());
  }

  final SwapBoltz _swapBoltz;
  final WalletTx _walletTx;
  final HomeCubit _homeCubit;
  final NetworkCubit _networkCubit;

  BoltzApi? _boltzMainnet;
  BoltzApi? _boltzTestnet;
  StreamSubscription? _mainNetStream;
  StreamSubscription? _testNetStream;

  @override
  Future<void> close() {
    _disposeAll();
    return super.close();
  }

  void _disposeAll() {
    _mainNetStream?.cancel();
    _testNetStream?.cancel();
    _boltzMainnet?.dispose();
    _boltzTestnet?.dispose();

    _boltzMainnet = null;
    _boltzTestnet = null;
    _mainNetStream = null;
    _testNetStream = null;
  }

  void _onWatchWallets(WatchWallets event, Emitter<WatchTxsState> emit) async {
    final isTestnet = _networkCubit.state.testnet;
    print('WatchWallets: istesntnet? $isTestnet');
    await Future.delayed(100.ms);
    final network = _networkCubit.state.getBBNetwork();
    final walletBlocs = _homeCubit.state.walletBlocsFromNetwork(network);
    final swapsToWatch = <SwapTx>[];
    for (final walletBloc in walletBlocs) {
      final wallet = walletBloc.state.wallet!;
      for (final swapTx in wallet.swapsToProcess())
        add(
          ProcessSwapTx(
            walletId: wallet.id,
            swapTxId: swapTx.id,
          ),
        );
      swapsToWatch.addAll(wallet.swaps);
    }
    swapsToWatch.removeWhere((_) => _.failed());
    if (swapsToWatch.isEmpty) return;
    print('Listening to Swaps: ${swapsToWatch.map((_) => _.id).toList()}');
    __watchSwapStatus(
      emit,
      swapTxsToWatch: swapsToWatch.map((_) => _.id).toList(),
      isTestnet: isTestnet,
    );
  }

  void __watchSwapStatus(
    Emitter<WatchTxsState> emit, {
    required List<String> swapTxsToWatch,
    required bool isTestnet,
  }) async {
    for (final swap in swapTxsToWatch) {
      final exists = state.isListening(swap);
      if (exists) continue;
      emit(state.copyWith(listeningTxs: [...state.listeningTxs, swap]));
    }

    _disposeAll();

    if (isTestnet) {
      final (watcherTestnet, errTestnet) =
          await _swapBoltz.initializeBoltzApi(true);
      if (errTestnet != null) {
        emit(state.copyWith(errWatchingInvoice: errTestnet.message));
        return;
      }

      _boltzTestnet = watcherTestnet;

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
      final (watcher, err) = await _swapBoltz.initializeBoltzApi(false);

      if (err != null) {
        emit(state.copyWith(errWatchingInvoice: err.message));
        return;
      }
      _boltzMainnet = watcher;

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
  }

  void __swapStatusUpdated(
    Emitter<WatchTxsState> emit, {
    required String swapId,
    required SwapStreamStatus status,
  }) async {
    print('----swapstatus : $swapId - ${status.status}');
    for (final walletBloc in _homeCubit.state.walletBlocs!) {
      if (walletBloc.state.wallet!.hasOngoingSwap(swapId)) {
        final id = swapId;
        print('SwapStatusUpdate: $id - ${status.status}');
        if (!state.isListeningId(id)) return;
        final swapTx = walletBloc.state.wallet!.getOngoingSwap(id);

        add(
          ProcessSwapTx(
            walletId: walletBloc.state.wallet!.id,
            status: status,
            swapTxId: swapTx!.id,
          ),
        );
      }
    }
  }

  Future<Wallet?> __updateWalletTxs(
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
        syncAfter: swapTx.syncWallet(),
        delaySync: 200,
        updateTypes: [
          UpdateWalletTypes.swaps,
          UpdateWalletTypes.transactions,
        ],
      ),
    );

    await Future.delayed(400.ms);
    return updatedWallet;
  }

  Future<SwapTx?> __refundSwap(
    SwapTx swapTx,
    WalletBloc walletBloc,
    Emitter<WatchTxsState> emit,
  ) async {
    if (state.swapRefunded(swapTx.id) || (state.isRefunding(swapTx.id))) {
      emit(state.copyWith(errRefundingSwap: 'Swap refunded/refunding'));
      return null;
    }

    final updatedRefundingTxs = state.addRefunding(swapTx.id);
    if (updatedRefundingTxs == null) return null;

    emit(
      state.copyWith(
        claimingSwap: true,
        errRefundingSwap: '',
        refundingSwapTxIds: updatedRefundingTxs,
      ),
    );

    // await Future.delayed(10.seconds);

    final (txid, err) = await _swapBoltz.refundV2SubmarineSwap(
      swapTx: swapTx,
      wallet: walletBloc.state.wallet!,
      tryCooperate: true,
    );
    if (err != null) {
      emit(
        state.copyWith(
          refundingSwap: false,
          errRefundingSwap: err.toString(),
          refundingSwapTxIds: state.removeRefunding(swapTx.id),
        ),
      );
      return null;
    }

    SwapTx updatedSwap;
    try {
      final json = jsonDecode(txid!) as Map<String, dynamic>;
      updatedSwap = swapTx.copyWith(
        txid: json['id'] as String,
        status: SwapStreamStatus(
          id: swapTx.id,
          status: SwapStatus.swapRefunded,
        ),
      );
    } catch (e) {
      updatedSwap = swapTx.copyWith(txid: txid);
    }

    emit(
      state.copyWith(
        refundedSwapTxs: [...state.refundedSwapTxs, updatedSwap.id],
        refundingSwapTxIds: state.removeRefunding(updatedSwap.id),
        refundingSwap: false,
        // syncWallet: walletBloc.state.wallet,
      ),
    );

    return updatedSwap;
  }

  Future<SwapTx?> __claimSwap(
    SwapTx swapTx,
    WalletBloc walletBloc,
    Emitter<WatchTxsState> emit,
  ) async {
    if (state.swapClaimed(swapTx.id) || (state.isClaiming(swapTx.id))) {
      emit(state.copyWith(errClaimingSwap: 'Swap claimed/claiming'));
      return null;
    }

    final updatedClaimingTxs = state.addClaiming(swapTx.id);
    if (updatedClaimingTxs == null) return null;

    emit(
      state.copyWith(
        claimingSwap: true,
        errClaimingSwap: '',
        claimingSwapTxIds: updatedClaimingTxs,
      ),
    );

    // await Future.delayed(5.seconds);

    final (txid, err) = await _swapBoltz.claimV2ReverseSwap(
      swapTx: swapTx,
      wallet: walletBloc.state.wallet!,
      tryCooperate: true,
    );
    if (err != null) {
      emit(
        state.copyWith(
          claimingSwap: false,
          errClaimingSwap: err.toString(),
          claimingSwapTxIds: state.removeClaiming(swapTx.id),
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
        claimingSwapTxIds: state.removeClaiming(updatedSwap.id),
        claimingSwap: false,
        // syncWallet: walletBloc.state.wallet,
      ),
    );

    return updatedSwap;
  }

  Future<SwapTx?> __coopCloseSwap(
    SwapTx swapTx,
    WalletBloc walletBloc,
    Emitter<WatchTxsState> emit,
  ) async {
    if (state.swapClaimed(swapTx.id) || (state.isClaiming(swapTx.id))) {
      emit(
        state.copyWith(
          errClaimingSwap: 'Submarine cooperative claim close complete.',
        ),
      );
      return null;
    }

    final updatedClaimingTxs = state.addClaiming(swapTx.id);
    if (updatedClaimingTxs == null) return null;

    emit(
      state.copyWith(
        claimingSwap: true,
        errClaimingSwap: '',
        claimingSwapTxIds: updatedClaimingTxs,
      ),
    );

    // await Future.delayed(7.seconds);

    final err = await _swapBoltz.cooperativeSubmarineClose(
      swapTx: swapTx,
      wallet: walletBloc.state.wallet!,
    );
    if (err != null) {
      // print(err);
      emit(
        state.copyWith(
          claimingSwap: false,
          errClaimingSwap: err.toString(),
          claimingSwapTxIds: state.removeClaiming(swapTx.id),
        ),
      );
      return null;
    }

    emit(
      state.copyWith(
        claimedSwapTxs: [...state.claimedSwapTxs, swapTx.id],
        claimingSwapTxIds: state.removeClaiming(swapTx.id),
        claimingSwap: false,
        // syncWallet: walletBloc.state.wallet,
      ),
    );
    return null;
  }

  // Future __swapAlert(
  //   SwapTx swapTx,
  //   Wallet wallet,
  //   Emitter<WatchTxsState> emit,
  // ) async {
  //   if (swapTx.paidReverse()) {
  //     print('ALERT Swap Paid Reverse');
  //     emit(state.copyWith(txPaid: swapTx));
  //     return;
  //   }

  //   if (swapTx.settledReverse()) {
  //     print('ALERT Swap Settled Reverse');
  //     emit(state.copyWith(syncWallet: wallet, txPaid: swapTx));
  //     return;
  //   }

  //   if (swapTx.paidSubmarine()) {
  //     print('ALERT Swap Paid Submarine');
  //     emit(state.copyWith(txPaid: swapTx));
  //     return;
  //   }

  //   if (swapTx.settledSubmarine()) {
  //     print('ALERT Swap Settled Submarine');
  //     emit(state.copyWith(syncWallet: wallet, txPaid: swapTx));
  //     return;
  //   }
  // }

  Future __closeSwap(
    SwapTx swapTx,
    Emitter<WatchTxsState> emit,
  ) async {
    emit(
      state.copyWith(listeningTxs: state.removeListeningTx(swapTx.id)),
    );
    // await Future.delayed(1500.ms);
    // final isTestnet = swapTx.network == BBNetwork.Testnet;
    // add(WatchWallets(isTestnet: isTestnet));
  }

  // Future<void> _onClearAlerts(
  //   ClearAlerts event,
  //   Emitter<WatchTxsState> emit,
  // ) async {
  //   emit(state.copyWith(txPaid: null, syncWallet: null));
  // }

  Future<void> _onProcessSwapTx(
    ProcessSwapTx event,
    Emitter<WatchTxsState> emit,
  ) async {
    // locator<Logger>().log('', printToConsole: true);

    final walletBloc = _homeCubit.state.getWalletBlocById(event.walletId);
    final wallet = walletBloc?.state.wallet;
    if (walletBloc == null || wallet == null) return;
    final swapFromWallet =
        walletBloc.state.wallet!.getOngoingSwap(event.swapTxId);
    final swapTx = event.status != null
        ? swapFromWallet!.copyWith(status: event.status)
        : swapFromWallet!;

    emit(state.copyWith(updatedSwapTx: swapTx));
    await Future.delayed(100.ms);
    emit(state.copyWith(updatedSwapTx: null));

    final liquidElectrum = _networkCubit.state.selectedLiquidNetwork;

    if (!swapTx.isSubmarine) {
      switch (swapTx.reverseSwapAction()) {
        case ReverseSwapActions.created:
          await __updateWalletTxs(swapTx, walletBloc, emit);

        case ReverseSwapActions.failed:
          await __updateWalletTxs(swapTx, walletBloc, emit);
          await __closeSwap(swapTx, emit);

        case ReverseSwapActions.paid:
          if (wallet.isLiquid() &&
              liquidElectrum == LiquidElectrumTypes.bullbitcoin) {
            final swap = await __claimSwap(swapTx, walletBloc, emit);
            if (swap != null) await __updateWalletTxs(swap, walletBloc, emit);
            return;
          }
          await __updateWalletTxs(swapTx, walletBloc, emit);

        case ReverseSwapActions.claimable:
          final swap = await __claimSwap(swapTx, walletBloc, emit);
          if (swap != null)
            await __updateWalletTxs(swap, walletBloc, emit);
          else
            await __updateWalletTxs(swapTx, walletBloc, emit);

        case ReverseSwapActions.settled:
          final w = await __updateWalletTxs(swapTx, walletBloc, emit);
          if (w == null) return;
          await __closeSwap(swapTx, emit);
      }
    } else {
      switch (swapTx.submarineSwapAction()) {
        case SubmarineSwapActions.created:
          await __updateWalletTxs(swapTx, walletBloc, emit);

        case SubmarineSwapActions.failed:
          await __updateWalletTxs(swapTx, walletBloc, emit);
          await __closeSwap(swapTx, emit);

        case SubmarineSwapActions.paid:
          if (swapTx.isLiquid()) {
            final swap = await __coopCloseSwap(swapTx, walletBloc, emit);
            if (swap != null) await __updateWalletTxs(swap, walletBloc, emit);
            return;
          } else
            await __updateWalletTxs(swapTx, walletBloc, emit);

        case SubmarineSwapActions.claimable:
          final swap = await __coopCloseSwap(swapTx, walletBloc, emit);
          if (swap != null)
            await __updateWalletTxs(swap, walletBloc, emit);
          else
            await __updateWalletTxs(swapTx, walletBloc, emit);
        case SubmarineSwapActions.refundable:
          await __updateWalletTxs(swapTx, walletBloc, emit);
          final swap = await __refundSwap(swapTx, walletBloc, emit);
          if (swap != null)
            await __updateWalletTxs(
              swap,
              walletBloc,
              emit,
            );

        case SubmarineSwapActions.settled:
          final w = await __updateWalletTxs(swapTx, walletBloc, emit);
          if (w == null) return;
          await __closeSwap(swapTx, emit);
      }
    }
  }
}
