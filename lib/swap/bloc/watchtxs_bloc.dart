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
    on<WatchInvoiceStatus>(_onWatchInvoiceStatus);
    on<UpdateOrClaimSwap>(_onUpdateOrClaimSwap, transformer: sequential());
    on<UpdateInvoiceStatus>(_onUpdateInvoiceStatus);
    on<DeleteSensitiveSwapTx>(_onDeleteSensitiveSwapTx);
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

    final (boltzWatcher, err) = await swapBoltz.createSwapWatcher();
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
    final walletBloc = homeCubit.state.getWalletBloc(event.walletBloc.state.wallet!);
    if (walletBloc == null) return;

    final swapTxs = walletBloc.state.allSwapTxs();
    final swapTxsToWatch = <SwapTx>[];
    for (final tx in swapTxs) {
      final status = tx.status?.status;
      if (status != null &&
          (status == SwapStatus.invoiceSettled ||
              status == SwapStatus.swapExpired ||
              status == SwapStatus.invoiceExpired ||
              status == SwapStatus.txnFailed ||
              status == SwapStatus.invoiceFailedToPay ||
              status == SwapStatus.txnLockupFailed)) continue;

      swapTxsToWatch.add(tx);
    }
    if (swapTxsToWatch.isEmpty) return;
    add(
      WatchInvoiceStatus(
        swapTx: swapTxsToWatch,
        walletBloc: walletBloc,
      ),
    ); // we dont need to pass the walletBloc anymore
  }

  void _onWatchInvoiceStatus(WatchInvoiceStatus event, Emitter<WatchTxsState> emit) async {
    if (state.boltzWatcher == null) {
      emit(
        state.copyWith(errWatchingInvoice: 'Watcher not initialized. Re-initializing. Try Again.'),
      );
      add(InitializeSwapWatcher());
      return;
    }
    final txs = event.swapTx;
    for (final tx in txs) {
      final exists = state.isListening(tx);
      if (exists) continue;
      emit(state.copyWith(listeningTxs: [...state.listeningTxs, tx]));
    }

    final err = await swapBoltz.updateSwapWatcher(
      api: state.boltzWatcher!,
      swapIds: txs.map((_) => _.id).toList(),
      onUpdate: (id, status) {
        // for (final wallet in homeCubit.state.wallets!) {
        // if (wallet.hasOngoingSwap(id)) {
        // final walletBloc = homeCubit.state.getWalletBloc(wallet);
        add(UpdateInvoiceStatus(id, status, event.walletBloc));
        // } else {
        // emit(state.copyWith(errWatchingInvoice: 'Could not match swap update with a wallet'));
        // }
        // }
      },
    );

    emit(state.copyWith(errWatchingInvoice: err.toString()));
    return;
  }

  void _onUpdateInvoiceStatus(UpdateInvoiceStatus event, Emitter<WatchTxsState> emit) async {
    for (final wallet in homeCubit.state.wallets!) {
      if (wallet.hasOngoingSwap(event.id)) {
        final walletBloc = homeCubit.state.getWalletBloc(wallet);
        if (walletBloc == null) return;

        final id = event.id;
        final status = event.status;
        print('UpdateInvoiceStatus: $id - ${status.status}');
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

        final close = status.status == SwapStatus.txnClaimed ||
            // status.status == SwapStatus.swapExpired || // this is not what we want for submarine. this is when we need to trigger refund
            status.status == SwapStatus.invoiceExpired ||
            status.status == SwapStatus.invoiceSettled;
        if (close) {
          final updatedTxs = state.listeningTxs.where((_) => _.id != id).toList();
          emit(state.copyWith(listeningTxs: updatedTxs));
        }
        add(UpdateOrClaimSwap(walletBloc: walletBloc, swapTx: tx));
      }
    }
  }

  FutureOr<void> _onUpdateOrClaimSwap(UpdateOrClaimSwap event, Emitter<WatchTxsState> emit) async {
    final walletBloc = event.walletBloc;
    // if (walletBloc == null) return;
    print('::: 1');

    // final status = event.status!; // not required since swapTx is updated with latest status
    final swapTx = event.swapTx;

    if (swapTx.status!.status.hasSettled) {
      print('::: 2');

      final wallet = walletBloc.state.wallet;
      if (wallet == null) return;
      final (updatedWallet, err) = await walletTransaction.mergeSwapTxIntoTx(
        wallet: wallet,
        swapTx: swapTx,
        swapBloc: this,
      );
      if (err != null) {
        print('::: 2-1');
        print('$err');
        emit(state.copyWith(errWatchingInvoice: err.toString()));
        return;
      }
      print('=::: 3');
      walletBloc.add(
        UpdateWallet(
          updatedWallet!,
          updateTypes: [UpdateWalletTypes.transactions, UpdateWalletTypes.swaps],
        ),
      );
      print('::: 4');

      // await Future.delayed(500.ms);
      print('::: 5');

      homeCubit.updateSelectedWallet(walletBloc);
      print('::: 6');

      // await Future.delayed(500.ms);
      print('>::: 7');

      return;
    }

    print('::: 8');

    final canClaim = swapTx.status!.status.canClaim;
    if (!canClaim) {
      print('::: 9');

      // await Future.delayed(1000.ms);
      print('::: 10');
      final wallet = homeCubit.state.getWalletBloc(walletBloc.state.wallet!);

      if (wallet == null) return;
      print('::: 11');

      final (updatedWallet, err) = walletTransaction.updateSwapTxs(
        wallet: wallet.state.wallet!,
        swapTx: swapTx,
      );
      if (err != null) {
        print('::: 11-1 - $err');

        emit(state.copyWith(errWatchingInvoice: err.toString()));
        return;
      }
      print('=::: 12');

      walletBloc.add(
        UpdateWallet(
          updatedWallet!,
          updateTypes: [UpdateWalletTypes.swaps],
        ),
      );
      print('::: 13');

      // await Future.delayed(500.ms);
      homeCubit.updateSelectedWallet(walletBloc);
      print('::: 14');

      // await Future.delayed(500.ms);
      print('>::: 15');

      return;
    }

    if (state.swapClaimed(swapTx)) {
      print('::: 16-0 - swapid:${swapTx.id}');
      emit(state.copyWith(errClaimingSwap: 'Swap claimed'));
      return;
    }

    print('::: 16');

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

    print('::: 17');

    final (fees, errFees) = await swapBoltz.getFeesAndLimits(
      boltzUrl: boltzTestnet,
      outAmount: swapTx.outAmount,
    );
    print('::: 18');

    if (errFees != null) {
      print('::: 19');

      emit(state.copyWith(claimingSwapSwap: false, errClaimingSwap: errFees.toString()));
      return;
    }
    print('::: 20');

    final claimFeesEstimate = fees?.btcReverse.claimFeesEstimate;
    if (claimFeesEstimate == null) {
      emit(
        state.copyWith(
          claimingSwapSwap: false,
          errClaimingSwap: 'Fees not found',
        ),
      );
      return;
    }
    print('::: 21');

    final (txid, err) = await swapBoltz.claimSwap(
      tx: swapTx,
      outAddress: address,
      absFee: claimFeesEstimate,
    );
    print('::: 22');
    if (err != null) {
      print('::: 23 - $err');
      emit(state.copyWith(claimingSwapSwap: false, errClaimingSwap: err.toString()));
      return;
    }

    emit(state.copyWith(claimedSwapTxs: [...state.claimedSwapTxs, swapTx]));

    print('::: 24');
    final tx = swapTx.copyWith(
      txid: txid,
    );
    final (updatedWallet, err1) =
        walletTransaction.updateSwapTxs(swapTx: tx, wallet: walletBloc.state.wallet!);
    if (err1 != null) {
      print('::: 24-1 - $err1');

      emit(state.copyWith(errClaimingSwap: err1.toString()));
      return;
    }

    print('=::: 25');
    walletBloc.add(
      UpdateWallet(
        updatedWallet!,
        updateTypes: [UpdateWalletTypes.swaps],
      ),
    );
    print('::: 26');
    emit(
      state.copyWith(
        claimingSwapSwap: false,
        errClaimingSwap: '',
      ),
    );
    print('::: 27');
    // await Future.delayed(500.ms);
    print('::: 28');

    homeCubit.updateSelectedWallet(walletBloc);
    print('::: 29');

    // await Future.delayed(500.ms);
    print('>::: 30');
  }

  void _onDeleteSensitiveSwapTx(
    DeleteSensitiveSwapTx event,
    Emitter<WatchTxsState> emit,
  ) async {
    final _ = await swapBoltz.deleteSwapSensitive(id: event.swapId);
  }
}
