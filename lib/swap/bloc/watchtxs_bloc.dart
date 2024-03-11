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

    // TODO: Sai: 'Sometimes' this is not returning all swaps
    // Sometimes -->
    //  When swap is created. Without app restart, this function is never invoked.
    final swapTxs = walletBloc.state.allSwapTxs();
    final swapTxsToWatch = <SwapTx>[];
    print('WatchWalletTxs: ${swapTxs.length}');
    for (final swapTx in swapTxs) {
      if (swapTx.settledSubmarine || swapTx.settledOrExpiredReverse) {
        add(UpdateOrClaimSwap(walletId: event.walletId, swapTx: swapTx));
        continue;
      }
      swapTxsToWatch.add(swapTx);
      // final exists = state.isListening(swapTx);
      // if (exists) continue;
      // emit(state.copyWith(listeningTxs: [...state.listeningTxs, swapTx]));
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

    // print('WatchSwapStatus: ${event.swapTxs}');
    for (final tx in event.swapTxs) {
      final exists = state.isListening(tx);
      if (exists) continue;
      emit(state.copyWith(listeningTxs: [...state.listeningTxs, tx]));
    }
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
    // TODO: Sai: This for loop can be avoided since we have event.walletId by doing
    // final walletBloc = homeCubit.state.getWalletBlocById(event.walletId);
    for (final walletBloc in homeCubit.state.walletBlocs!) {
      if (walletBloc.state.wallet!.hasOngoingSwap(event.swapId)) {
        final id = event.swapId;
        final status = event.status;
        print('SwapStatusUpdate: $id - ${status.status}');
        if (!state.isListeningId(id)) return;

        final swapTx = state.listeningTxs.firstWhere((_) => _.id == id).copyWith(status: status);
        emit(
          state.copyWith(
            listeningTxs: state.listeningTxs
                .map(
                  (_) => _.id == id ? swapTx : _,
                )
                .toList(),
          ),
        );

        final close = swapTx.settledOrExpiredReverse || swapTx.settledSubmarine;
        if (close) {
          final idx = state.listeningTxs.indexWhere((element) => element.id == swapTx.id);
          if (idx != -1) {
            final newListeningTxs =
                state.listeningTxs.where((element) => element.id != swapTx.id).toList();
            emit(
              state.copyWith(
                listeningTxs: newListeningTxs,
              ),
            );
          }
        }
        add(UpdateOrClaimSwap(walletId: event.walletId, swapTx: swapTx));
      }
    }
  }

  FutureOr<void> _onUpdateOrClaimSwap(UpdateOrClaimSwap event, Emitter<WatchTxsState> emit) async {
    final walletBloc = homeCubit.state.getWalletBlocById(event.walletId);
    if (walletBloc == null) return;
    final wallet = walletBloc.state.wallet;
    if (wallet == null) return;
    final SwapTx swapTx = event.swapTx;
    // print('_onUpdateOrClaimSwap: ${swapTx.id}');

    if (swapTx.status!.status.reverseSettled || swapTx.settledSubmarine) {
      // if (swapTx.txid == null) {
      //   // TODO: Sai: This is throwing error 'Bad state: No element' for completed swaps;
      //   swapTx = state.claimedSwapTxs.firstWhere((element) => element.id == swapTx.id);
      // }
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
      // } else if (swapTx.status!.status == SwapStatus.txnClaimed ||
      //     swapTx.status!.status == SwapStatus.txnMempool) {
      //   if (swapTx.txid == null) {
      //     swapTx = state.listeningTxs.firstWhere((element) => element.id == swapTx.id);
      //   }
      //   final (walletAndTxs, err) = await walletTransaction.mergeSwapTxIntoTx(
      //     wallet: wallet,
      //     swapTx: swapTx,
      //   );
      //   if (err != null) {
      //     emit(state.copyWith(errWatchingInvoice: err.toString()));
      //     return;
      //   }
      //   final updatedWallet = walletAndTxs!.wallet;
      //   final swapsToDelete = walletAndTxs.swapsToDelete;
      //   walletBloc.add(
      //     UpdateWallet(
      //       updatedWallet,
      //       updateTypes: [UpdateWalletTypes.transactions, UpdateWalletTypes.swaps],
      //     ),
      //   );
      //   homeCubit.updateSelectedWallet(walletBloc);
      //   if (swapTx.status?.status == SwapStatus.txnConfirmed)
      //     for (final swap in swapsToDelete) add(DeleteSensitiveSwapData(swap.id));
      //   return;
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

    emit(state.copyWith(claimingSwap: true, errClaimingSwap: ''));

    final address = walletBloc.state.wallet?.lastGeneratedAddress?.address;
    if (address == null || address.isEmpty) {
      emit(
        state.copyWith(
          claimingSwap: false,
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
      emit(state.copyWith(claimingSwap: false, errClaimingSwap: errFees.toString()));
      return;
    }

    final claimFeesEstimate =
        shouldRefund ? fees?.btcSubmarine.claimFees : fees?.btcReverse.claimFeesEstimate;
    if (claimFeesEstimate == null) {
      emit(
        state.copyWith(
          claimingSwap: false,
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
        emit(state.copyWith(claimingSwap: false, errClaimingSwap: err.toString()));
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
        emit(state.copyWith(claimingSwap: false, errClaimingSwap: err.toString()));
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
        claimingSwap: false,
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
