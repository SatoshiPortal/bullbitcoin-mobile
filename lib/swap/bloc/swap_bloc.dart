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
import 'package:bb_mobile/swap/bloc/swap_event.dart';
import 'package:bb_mobile/swap/bloc/swap_state.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:boltz_dart/boltz_dart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SwapBloc extends Bloc<SwapEvent, SwapState> {
  SwapBloc({
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
  }) : super(const SwapState()) {
    on<CreateBtcLightningSwap>(_onCreateBtcLightningSwap);
    on<SaveSwapInvoiceToWallet>(_onSaveSwapInvoiceToWallet);
    on<WatchInvoiceStatus>(_onWatchInvoiceStatus, transformer: concurrent());
    on<UpdateOrClaimSwap>(_onUpdateOrClaimSwap, transformer: sequential());
    on<UpdateInvoiceStatus>(_onUpdateInvoiceStatus);
    on<ResetToNewLnInvoice>(_onResetToNewLnInvoice);
    on<DeleteSensitiveSwapTx>(_onDeleteSensitiveSwapTx);
    on<WatchWalletTxs>(_onWatchWalletTxs);
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

  void _onCreateBtcLightningSwap(CreateBtcLightningSwap event, Emitter<SwapState> emit) async {
    if (!networkCubit.state.testnet) return;

    final walletBloc = homeCubit.state.getWalletBloc(event.walletBloc.state.wallet!);
    if (walletBloc == null) return;

    final outAmount = event.amount;
    if (outAmount < 50000 || outAmount > 25000000) {
      emit(
        state.copyWith(
          errCreatingSwapInv: 'Amount should be greater than 50000 and less than 25000000 sats',
          generatingSwapInv: false,
        ),
      );
      return;
    }

    emit(state.copyWith(generatingSwapInv: true, errCreatingSwapInv: ''));
    final (seed, errReadingSeed) = await walletSensitiveRepository.readSeed(
      fingerprintIndex: walletBloc.state.wallet!.getRelatedSeedStorageString(),
      secureStore: secureStorage,
    );
    if (errReadingSeed != null) {
      emit(state.copyWith(errCreatingSwapInv: errReadingSeed.toString(), generatingSwapInv: false));
      return;
    }
    final (fees, errFees) = await swapBoltz.getFeesAndLimits(
      boltzUrl: boltzTestnet,
      outAmount: outAmount,
    );
    if (errFees != null) {
      emit(state.copyWith(errCreatingSwapInv: errFees.toString(), generatingSwapInv: false));
      return;
    }

    final (swap, errCreatingInv) = await swapBoltz.receive(
      mnemonic: seed!.mnemonic,
      index: walletBloc.state.wallet!.swapTxCount,
      outAmount: outAmount,
      network: Chain.Testnet,
      electrumUrl: networkCubit.state.getNetworkUrl(),
      boltzUrl: boltzTestnet,
      pairHash: fees!.btcPairHash,
    );
    if (errCreatingInv != null) {
      emit(state.copyWith(errCreatingSwapInv: errCreatingInv.toString(), generatingSwapInv: false));
      return;
    }

    emit(state.copyWith(generatingSwapInv: false, errCreatingSwapInv: '', swapTx: swap));

    add(SaveSwapInvoiceToWallet(swapTx: swap!, label: event.label, walletBloc: walletBloc));
  }

  void _onSaveSwapInvoiceToWallet(SaveSwapInvoiceToWallet event, Emitter<SwapState> emit) async {
    final walletBloc = homeCubit.state.getWalletBloc(event.walletBloc.state.wallet!);
    if (walletBloc == null) return;

    final wallet = walletBloc.state.wallet;
    if (wallet == null) return;

    final swapTxCount = wallet.swapTxCount + 1;
    final tx = Transaction.fromSwapTx(event.swapTx).copyWith(
      isSwap: true,
      swapIndex: wallet.swapTxCount,
      label: event.label,
    );

    final (updatedWallet, err) = await walletTx.addSwapTxToWallet(
      wallet: wallet.copyWith(swapTxCount: swapTxCount),
      transaction: tx,
    );
    if (err != null) {
      emit(state.copyWith(errCreatingSwapInv: err.toString(), generatingSwapInv: false));
      return;
    }

    walletBloc.add(
      UpdateWallet(
        updatedWallet,
        updateTypes: [UpdateWalletTypes.swaps],
      ),
    );

    // await Future.delayed(100.ms);

    // homeCubit?.updateSelectedWallet(walletBloc);

    add(WatchInvoiceStatus(tx: tx, walletBloc: walletBloc));
  }

  void _onResetToNewLnInvoice(ResetToNewLnInvoice event, Emitter<SwapState> emit) =>
      emit(state.copyWith(swapTx: null));

  void _onWatchWalletTxs(WatchWalletTxs event, Emitter<SwapState> emit) {
    final walletBloc = homeCubit.state.getWalletBloc(event.walletBloc.state.wallet!);
    if (walletBloc == null) return;

    final swapTxs = walletBloc.state.allSwapTxs();
    for (final tx in swapTxs) {
      if (tx.swapTx == null) continue;
      final status = tx.swapTx!.status?.status;
      if (status != null &&
          (status == SwapStatus.invoiceSettled ||
              status == SwapStatus.swapExpired ||
              status == SwapStatus.invoiceExpired ||
              status == SwapStatus.txnFailed ||
              status == SwapStatus.invoiceFailedToPay ||
              status == SwapStatus.txnLockupFailed)) continue;

      add(WatchInvoiceStatus(tx: tx, walletBloc: walletBloc));
    }
  }

  void _onWatchInvoiceStatus(WatchInvoiceStatus event, Emitter<SwapState> emit) async {
    final swap = event.tx.swapTx;
    if (swap == null) return;

    if (state.listeningTxs.any((_) => swap.id == _.id)) return;

    emit(state.copyWith(listeningTxs: [...state.listeningTxs, swap]));
    final err = await swapBoltz.watchSwap(
      swapId: swap.id,
      onUpdate: (id, status) {
        add(UpdateInvoiceStatus(id, status, event.walletBloc));
      },
    );
    if (err != null) {
      emit(state.copyWith(errWatchingInvoice: err.toString()));
      return;
    }
  }

  void _onUpdateInvoiceStatus(UpdateInvoiceStatus event, Emitter<SwapState> emit) async {
    final walletBloc = homeCubit.state.getWalletBloc(event.walletBloc.state.wallet!);
    if (walletBloc == null) return;

    final id = event.id;
    final status = event.status;
    if (!state.listeningTxs.any((_) => id == _.id)) return;

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
        status.status == SwapStatus.swapExpired ||
        status.status == SwapStatus.invoiceExpired;

    add(UpdateOrClaimSwap(walletBloc: walletBloc, swapTx: tx, status: status));

    if (close) {
      final errClose = swapBoltz.closeStream(id);
      if (errClose != null) {
        emit(state.copyWith(errWatchingInvoice: errClose.toString()));
        return;
      }
      final updatedTxs = state.listeningTxs.where((_) => _.id != id).toList();
      emit(state.copyWith(listeningTxs: updatedTxs));
      return;
    }
  }

  void _onUpdateOrClaimSwap(UpdateOrClaimSwap event, Emitter<SwapState> emit) async {
    final walletBloc = homeCubit.state.getWalletBloc(event.walletBloc.state.wallet!);
    if (walletBloc == null) return;

    final status = event.status;
    final swapTx = event.swapTx;

    if (status == null || swapTx == null) {
      final wallet = walletBloc.state.wallet;
      if (wallet == null) return;
      final (updatedWallet, err) = await walletTransaction.mergeSwapTxIntoTx(wallet: wallet);
      if (err != null) {
        emit(state.copyWith(errWatchingInvoice: err.toString()));
        return;
      }
      walletBloc.add(
        UpdateWallet(
          updatedWallet!,
          updateTypes: [UpdateWalletTypes.transactions, UpdateWalletTypes.swaps],
        ),
      );
      await Future.delayed(500.ms);
      homeCubit.updateSelectedWallet(walletBloc);
      await Future.delayed(500.ms);
      return;
    }

    final canClaim = status.status.canClaim;
    if (!canClaim) {
      await Future.delayed(1000.ms);
      final wallet = homeCubit.state.getWalletBloc(walletBloc.state.wallet!);
      if (wallet == null) return;
      final updatedWallet = wallet.state.wallet!.updateSwapTxs(swapTx);
      walletBloc.add(
        UpdateWallet(
          updatedWallet,
          updateTypes: [UpdateWalletTypes.swaps],
        ),
      );
      await Future.delayed(500.ms);
      homeCubit.updateSelectedWallet(walletBloc);
      await Future.delayed(500.ms);
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

    final (txid, err) = await swapBoltz.claimSwap(
      tx: swapTx,
      outAddress: address,
      absFee: claimFeesEstimate,
    );
    if (err != null) {
      emit(state.copyWith(claimingSwapSwap: false, errClaimingSwap: err.toString()));
      return;
    }

    final tx = swapTx.copyWith(txid: txid);
    final updatedWallet = walletBloc.state.wallet!.updateSwapTxs(tx);

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

    homeCubit.updateSelectedWallet(walletBloc);
    await Future.delayed(500.ms);
  }

  void _onDeleteSensitiveSwapTx(
    DeleteSensitiveSwapTx event,
    Emitter<SwapState> emit,
  ) async {
    final _ = await swapBoltz.deleteSwapSensitive(id: event.swapId);
  }
}
