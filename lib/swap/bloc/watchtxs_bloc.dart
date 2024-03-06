import 'dart:async';

import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/repository.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_event.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_state.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:boltz_dart/boltz_dart.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WatchTxsBloc extends Bloc<WatchTxsEvent, WatchTxsState> {
  WatchTxsBloc({
    required this.hiveStorage,
    required this.secureStorage,
    required this.walletAddress,
    required this.walletRepository,
    required this.walletSensitiveRepository,
    required this.settingsCubit,
    required this.networkCubit,
    required this.swapBoltz,
    required this.walletTx,
    required this.walletTransaction,
  }) : super(const WatchTxsState()) {
    on<InitializeSwapWatcher>(_initializeSwapWatcher);
    on<WatchSwapStatus>(_onWatchSwapStatus);
    on<UpdateOrClaimSwap>(_onUpdateOrClaimSwap, transformer: sequential());
    on<SwapStatusUpdate>(_onSwapStatusUpdate);
    on<DeleteSensitiveSwapData>(_onDeleteSensitiveSwapData);
    on<WatchWalletTxs>(_onWatchWalletTxs);
    add(InitializeSwapWatcher());
  }

  final SettingsCubit settingsCubit;
  final WalletAddress walletAddress;
  final HiveStorage hiveStorage;
  final SecureStorage secureStorage;
  final WalletRepository walletRepository;
  final WalletSensitiveRepository walletSensitiveRepository;
  final WalletTx walletTransaction;
  final NetworkCubit networkCubit;
  final SwapBoltz swapBoltz;
  final WalletTx walletTx;
  late HomeCubit homeCubit;

  void _initializeSwapWatcher(InitializeSwapWatcher event, Emitter<WatchTxsState> emit) async {
    if (state.boltzWatcher != null) return;

    final (boltzWatcher, err) = await swapBoltz.initializeBoltzApi();
    if (err != null) {
      emit(
        state.copyWith(
          errWatchingInvoice: err.message,
        ),
      );
    }
    emit(
      state.copyWith(
        boltzWatcher: boltzWatcher,
      ),
    );
  }

  void _onWatchWalletTxs(WatchWalletTxs event, Emitter<WatchTxsState> emit) {
    final walletBloc = homeCubit.state.getWalletBlocById(event.walletId);
    if (walletBloc == null) return;

    final swapTxs = walletBloc.state.allSwapTxs();
    final swapTxsToWatch = <SwapTx>[];
    for (final tx in swapTxs) {
      final status = tx.status?.status;
      if (status != null &&
          (status == SwapStatus.swapExpired ||
              status == SwapStatus.invoiceExpired ||
              status == SwapStatus.txnFailed ||
              status == SwapStatus.invoiceFailedToPay ||
              status == SwapStatus.txnLockupFailed ||
              status == SwapStatus.invoiceSettled)) continue;

      swapTxsToWatch.add(tx);

      if (status != null && (status == SwapStatus.invoiceSettled))
        add(UpdateOrClaimSwap(walletId: event.walletId, swapTx: tx));
    }
    if (swapTxsToWatch.isEmpty) return;
    add(
      WatchSwapStatus(
        swapTxs: swapTxsToWatch,
        walletId: event.walletId,
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
    for (final tx in event.swapTxs) {
      final exists = state.isListening(tx);
      if (exists) continue;
      emit(state.copyWith(listeningTxs: [...state.listeningTxs, tx]));
    }
    // this maybe called repeatedly
    // we should know what we are already listening for over wss and not update unless we have a new swap
    // seems like now we keep updating even if there isnt a new swap to listen to
    final err = await swapBoltz.addSwapSubs(
      api: state.boltzWatcher!,
      swapIds: event.swapTxs.map((_) => _.id).toList(),
      onUpdate: (id, status) {
        add(SwapStatusUpdate(id, status, event.walletId));
      },
    );

    emit(state.copyWith(errWatchingInvoice: err.toString()));
    return;
  }

  void _onSwapStatusUpdate(SwapStatusUpdate event, Emitter<WatchTxsState> emit) async {
    for (final walletBloc in homeCubit.state.walletBlocs!) {
      if (walletBloc.state.wallet!.hasOngoingSwap(event.swapId)) {
        final id = event.swapId;
        final status = event.status;
        print('SwapStatusUpdate: $id - ${status.status}');
        if (!state.isListeningId(id)) return;

        final tx = state.listeningTxs.firstWhere((_) => _.id == id).copyWith(status: status);
        emit(
          state.copyWith(
            listeningTxs: state.listeningTxs
                .map(
                  (_) => _.id == id ? tx : _,
                )
                .toList(),
          ),
        );

        // final close = status.status == SwapStatus.txnClaimed ||
        //     // status.status == SwapStatus.swapExpired || // this is not what we want for submarine. this is when we need to trigger refund
        //     status.status == SwapStatus.invoiceExpired ||
        //     status.status == SwapStatus.invoiceSettled;
        // if (close) {
        //   final updatedTxs = state.listeningTxs.where((_) => _.id != id).toList();
        //   emit(state.copyWith(listeningTxs: updatedTxs));
        // }
        add(UpdateOrClaimSwap(walletId: event.walletId, swapTx: tx));
      }
    }
  }

  FutureOr<void> _onUpdateOrClaimSwap(UpdateOrClaimSwap event, Emitter<WatchTxsState> emit) async {
    final walletBloc = homeCubit.state.getWalletBlocById(event.walletId);
    if (walletBloc == null) return;
    final wallet = walletBloc.state.wallet;
    if (wallet == null) return;
    SwapTx swapTx = event.swapTx;

    if (swapTx.status!.status.reverseSettled || swapTx.paidSubmarine) {
      if (swapTx.txid == null) {
        swapTx = state.claimedSwapTxs.firstWhere((element) => element.id == swapTx.id);
      }
      final (walletAndTxs, err) = await walletTransaction.mergeSwapTxIntoTx(
        wallet: wallet,
        swapTx: swapTx,
      );
      if (err != null) {
        emit(state.copyWith(errWatchingInvoice: err.toString()));
        return;
      }
      final updatedWallet = walletAndTxs!.wallet;
      final swapsToDelete = walletAndTxs.swapsToDelete;
      walletBloc.add(
        UpdateWallet(
          updatedWallet,
          updateTypes: [UpdateWalletTypes.transactions, UpdateWalletTypes.swaps],
        ),
      );
      homeCubit.updateSelectedWallet(walletBloc);
      for (final swap in swapsToDelete) add(DeleteSensitiveSwapData(swap.id));
      return;
    }

    final canClaim = swapTx.canClaim;
    var shouldRefund = false;
    if (!canClaim) {
      final (resp, err) = walletTransaction.updateSwapTxs(
        wallet: wallet,
        swapTx: swapTx,
      );
      if (err != null) {
        emit(state.copyWith(errWatchingInvoice: err.toString()));
        return;
      }
      final updatedWallet = resp!.wallet;
      if (resp.swapsToRefund.isEmpty) {
        walletBloc.add(
          UpdateWallet(
            updatedWallet,
            updateTypes: [UpdateWalletTypes.swaps],
          ),
        );
        homeCubit.updateSelectedWallet(walletBloc);
        return;
      }
      shouldRefund = true;
    }

    if (state.swapClaimed(swapTx)) {
      emit(state.copyWith(errClaimingSwap: 'Swap claimed'));
      return;
    }

    emit(state.copyWith(claimingSwapSwap: true, errClaimingSwap: ''));

    final address = walletBloc.state.wallet?.lastGeneratedAddress?.address;
    if (address == null || address.isEmpty) {
      emit(
        state.copyWith(
          claimingSwapSwap: false,
          errClaimingSwap: 'Address not found',
        ),
      );
      return;
    }

    final (fees, errFees) = await swapBoltz.getFeesAndLimits(
      boltzUrl: boltzTestnet,
      outAmount: swapTx.outAmount,
    );

    if (errFees != null) {
      emit(state.copyWith(claimingSwapSwap: false, errClaimingSwap: errFees.toString()));
      return;
    }

    final claimFeesEstimate =
        shouldRefund ? fees?.btcSubmarine.claimFees : fees?.btcReverse.claimFeesEstimate;
    if (claimFeesEstimate == null) {
      emit(
        state.copyWith(
          claimingSwapSwap: false,
          errClaimingSwap: 'Fees not found',
        ),
      );
      return;
    }

    var txid = '';
    if (!shouldRefund) {
      final (claimTxid, err) = await swapBoltz.claimSwap(
        tx: swapTx,
        outAddress: address,
        absFee: claimFeesEstimate,
      );
      if (err != null) {
        emit(state.copyWith(claimingSwapSwap: false, errClaimingSwap: err.toString()));
        return;
      }
      txid = claimTxid!;
    } else {
      final (refundTxid, err) = await swapBoltz.refundSwap(
        tx: swapTx,
        outAddress: address,
        absFee: claimFeesEstimate,
      );
      if (err != null) {
        emit(state.copyWith(claimingSwapSwap: false, errClaimingSwap: err.toString()));
        return;
      }
      txid = refundTxid!;
    }

    final tx = swapTx.copyWith(
      txid: txid,
    );
    emit(state.copyWith(claimedSwapTxs: [...state.claimedSwapTxs, tx]));

    final (resp, err1) = walletTransaction.updateSwapTxs(swapTx: tx, wallet: wallet);
    if (err1 != null) {
      emit(state.copyWith(errClaimingSwap: err1.toString()));
      return;
    }

    final updatedWallet = resp!.wallet;

    walletBloc.add(
      UpdateWallet(
        updatedWallet,
        updateTypes: [UpdateWalletTypes.swaps],
      ),
    );
    emit(
      state.copyWith(
        claimingSwapSwap: false,
        errClaimingSwap: '',
      ),
    );
    // await Future.delayed(500.ms);

    homeCubit.updateSelectedWallet(walletBloc);

    // await Future.delayed(500.ms);
  }

  void _onDeleteSensitiveSwapData(
    DeleteSensitiveSwapData event,
    Emitter<WatchTxsState> emit,
  ) async {
    final _ = await swapBoltz.deleteSwapSensitive(id: event.swapId);
  }
}
