import 'dart:async';
import 'dart:convert';

import 'package:bb_mobile/_model/network.dart';
import 'package:bb_mobile/_model/swap.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/logger.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_repositories/app_wallets_repository.dart';
import 'package:bb_mobile/_repositories/network_repository.dart';
import 'package:bb_mobile/_repositories/wallet_service.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_event.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_state.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:boltz/boltz.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WatchTxsBloc extends Bloc<WatchTxsEvent, WatchTxsState> {
  WatchTxsBloc({
    required SwapBoltz swapBoltz,
    required WalletTx walletTx,
    required NetworkRepository networkRepository,
    required AppWalletsRepository appWalletsRepository,
  })  : _walletTx = walletTx,
        _appWalletsRepository = appWalletsRepository,
        _networkRepository = networkRepository,
        _swapBoltz = swapBoltz,
        super(const WatchTxsState()) {
    on<WatchWallets>(_onWatchWallets);

    on<ProcessSwapTx>(_onProcessSwapTx, transformer: sequential());
  }

  final SwapBoltz _swapBoltz;
  final WalletTx _walletTx;

  final NetworkRepository _networkRepository;
  final AppWalletsRepository _appWalletsRepository;

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

  Future<void> _onWatchWallets(
    WatchWallets event,
    Emitter<WatchTxsState> emit,
  ) async {
    final isTestnet = _networkRepository.testnet;

    await Future.delayed(100.ms);
    final network = _networkRepository.getBBNetwork;

    final wallets = _appWalletsRepository.walletsFromNetwork(network);

    final swapsToWatch = <SwapTx>[];
    for (final wallet in wallets) {
      swapsToWatch.addAll(wallet.swaps);
    }

    if (swapsToWatch.isEmpty) return;

    _disposeAll();

    __watchSwapStatus(
      emit,
      swapTxsToWatch: swapsToWatch.map((_) => _.id).toList(),
      isTestnet: isTestnet,
    );
  }

  Future<void> __watchSwapStatus(
    Emitter<WatchTxsState> emit, {
    required List<String> swapTxsToWatch,
    required bool isTestnet,
  }) async {
    for (final swap in swapTxsToWatch) {
      final exists = state.isListening(swap);
      if (exists) continue;
      emit(state.copyWith(listeningTxs: [...state.listeningTxs, swap]));
    }

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

  Future<void> __swapStatusUpdated(
    Emitter<WatchTxsState> emit, {
    required String swapId,
    required SwapStreamStatus status,
  }) async {
    for (final wallet in _appWalletsRepository.allWallets) {
      if (wallet.hasOngoingSwap(swapId)) {
        if (!state.isListeningId(swapId)) return;

        add(
          ProcessSwapTx(
            walletId: wallet.id,
            status: status,
            swapTxId: swapId,
          ),
        );
      }
    }
  }

  Future<Wallet?> __updateWalletTxs(
    SwapTx swapTx,
    Wallet wallet,
    Emitter<WatchTxsState> emit,
  ) async {
    final (resp, err) = _walletTx.updateSwapTxs(
      wallet: wallet,
      swapTx: swapTx,
    );
    if (err != null) {
      emit(state.copyWith(errWatchingInvoice: err.toString()));
      return null;
    }
    final updatedWallet = resp!.wallet;

    await _appWalletsRepository.getWalletServiceById(wallet.id)?.updateWallet(
      updatedWallet,
      syncAfter: swapTx.syncWallet(),
      delaySync: 200,
      updateTypes: [
        UpdateWalletTypes.swaps,
        UpdateWalletTypes.transactions,
      ],
    );

    return updatedWallet;
  }

  Future<SwapTx?> __refundSwap(
    SwapTx swapTx,
    Wallet wallet,
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

    final broadcastViaBoltz = _networkRepository.data.selectedLiquidNetwork !=
        LiquidElectrumTypes.bullbitcoin;

    final (txid, err) = await _swapBoltz.refundSubmarineSwap(
      swapTx: swapTx,
      wallet: wallet,
      tryCooperate: true,
      broadcastViaBoltz: broadcastViaBoltz,
    );
    if (err != null) {
      locator<Logger>()
          .log('Error Refunding Submarine Swap ${swapTx.id}: $err');

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
        claimTxid: json['id'] as String,
        status: SwapStreamStatus(
          id: swapTx.id,
          status: SwapStatus.swapRefunded,
        ),
      );
    } catch (e) {
      updatedSwap = swapTx.copyWith(
        claimTxid: txid,
        status: SwapStreamStatus(
          id: swapTx.id,
          status: SwapStatus.swapRefunded,
        ),
      );
    }

    emit(
      state.copyWith(
        refundedSwapTxs: [...state.refundedSwapTxs, updatedSwap.id],
        refundingSwapTxIds: state.removeRefunding(updatedSwap.id),
        refundingSwap: false,
      ),
    );

    return updatedSwap;
  }

  Future<SwapTx?> __claimSwap(
    SwapTx swapTx,
    Wallet wallet,
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

    final broadcastViaBoltz = _networkRepository.data.selectedLiquidNetwork !=
        LiquidElectrumTypes.bullbitcoin;

    final (txid, err) = await _swapBoltz.claimReverseSwap(
      swapTx: swapTx,
      wallet: wallet,
      tryCooperate: true,
      broadcastViaBoltz: broadcastViaBoltz,
    );

    if (err != null) {
      locator<Logger>().log('Error Claiming Reverse Swap ${swapTx.id}: $err');

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
      updatedSwap = swapTx.copyWith(claimTxid: json['id'] as String);
    } catch (e) {
      updatedSwap = swapTx.copyWith(claimTxid: txid);
    }

    emit(
      state.copyWith(
        claimedSwapTxs: [...state.claimedSwapTxs, updatedSwap.id],
        claimingSwapTxIds: state.removeClaiming(updatedSwap.id),
        claimingSwap: false,
      ),
    );

    return updatedSwap;
  }

  Future<SwapTx?> __coopCloseSwap(
    SwapTx swapTx,
    Wallet wallet,
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

    final err = await _swapBoltz.cooperativeSubmarineClose(
      swapTx: swapTx,
      wallet: wallet,
    );
    if (err != null) {
      locator<Logger>()
          .log('Error Coop Closing Submarine Swap ${swapTx.id}: $err');

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
      ),
    );
    return null;
  }

  Future __closeSwap(
    SwapTx swapTx,
    Emitter<WatchTxsState> emit,
  ) async {
    emit(
      state.copyWith(listeningTxs: state.removeListeningTx(swapTx.id)),
    );
  }

  Future<SwapTx?> __onChainclaimSwap(
    SwapTx swapTx,
    Wallet wallet,
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

    final (txid, err) = await _swapBoltz.claimChainSwap(
      swapTx: swapTx,
      wallet: wallet,
      tryCooperate: true,
    );

    if (err != null) {
      locator<Logger>().log('Error Claiming Chain Swap ${swapTx.id}: $err');
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
      updatedSwap = swapTx.copyWith(claimTxid: json['id'] as String);
    } catch (e) {
      updatedSwap = swapTx.copyWith(claimTxid: txid);
    }

    emit(
      state.copyWith(
        claimedSwapTxs: [...state.claimedSwapTxs, updatedSwap.id],
        claimingSwapTxIds: state.removeClaiming(updatedSwap.id),
        claimingSwap: false,
      ),
    );

    return updatedSwap;
  }

  Future<SwapTx?> __onchainRefund(
    SwapTx swapTx,
    Wallet wallet,
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

    final (txid, err) = await _swapBoltz.refundChainSwap(
      swapTx: swapTx,
      wallet: wallet,
      tryCooperate: true,
    );
    if (err != null) {
      locator<Logger>().log('Error Refunding Chain Swap ${swapTx.id}: $err');

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

    updatedSwap = swapTx.copyWith(
      claimTxid: txid,
      status: SwapStreamStatus(
        id: swapTx.id,
        status: SwapStatus.swapRefunded,
      ),
    );

    emit(
      state.copyWith(
        refundedSwapTxs: [...state.refundedSwapTxs, updatedSwap.id],
        refundingSwapTxIds: state.removeRefunding(updatedSwap.id),
        refundingSwap: false,
      ),
    );

    return updatedSwap;
  }

  Future<void> _onProcessSwapTx(
    ProcessSwapTx event,
    Emitter<WatchTxsState> emit,
  ) async {
    final wallet = _appWalletsRepository.getWalletById(event.walletId);

    if (wallet == null) return;
    final SwapTx? swapFromWallet = wallet.getOngoingSwap(event.swapTxId);

    if (swapFromWallet == null) return;

    final swapTx = event.status != null
        ? swapFromWallet.copyWith(status: event.status)
        : swapFromWallet;

    locator<Logger>().log(
      'Process Swap ${swapTx.id}: ${swapTx.status!.status}',
      printToConsole: true,
    );

    emit(state.copyWith(updatedSwapTx: swapTx));

    if (swapTx.isReverse()) {
      switch (swapTx.reverseSwapAction()) {
        case ReverseSwapActions.created:
          await __updateWalletTxs(swapTx, wallet, emit);

        case ReverseSwapActions.failed:
          await __updateWalletTxs(swapTx, wallet, emit);
          await __closeSwap(swapTx, emit);

        case ReverseSwapActions.paid:
          if (wallet.isLiquid()) {
            final swap = await __claimSwap(swapTx, wallet, emit);
            if (swap != null) await __updateWalletTxs(swap, wallet, emit);
            break;
          }
          await __updateWalletTxs(swapTx, wallet, emit);

        case ReverseSwapActions.claimable:
          final swap = await __claimSwap(swapTx, wallet, emit);
          if (swap != null) {
            await __updateWalletTxs(swap, wallet, emit);
          } else {
            await __updateWalletTxs(swapTx, wallet, emit);
          }

        case ReverseSwapActions.settled:
          final updatedSwapTx = swapTx.copyWith(completionTime: DateTime.now());
          final w = await __updateWalletTxs(updatedSwapTx, wallet, emit);
          if (w == null) break;
          await __closeSwap(updatedSwapTx, emit);
      }
    } else if (swapTx.isSubmarine()) {
      switch (swapTx.submarineSwapAction()) {
        case SubmarineSwapActions.created:
          await __updateWalletTxs(swapTx, wallet, emit);

        case SubmarineSwapActions.failed:
          await __updateWalletTxs(swapTx, wallet, emit);
          await __closeSwap(swapTx, emit);

        case SubmarineSwapActions.paid:
          if (swapTx.isLiquid()) {
            final swap = await __coopCloseSwap(swapTx, wallet, emit);
            if (swap != null) await __updateWalletTxs(swap, wallet, emit);
            break;
          } else {
            await __updateWalletTxs(swapTx, wallet, emit);
          }

        case SubmarineSwapActions.claimable:
          final swap = await __coopCloseSwap(swapTx, wallet, emit);
          if (swap != null) {
            await __updateWalletTxs(swap, wallet, emit);
          } else {
            await __updateWalletTxs(swapTx, wallet, emit);
          }

        case SubmarineSwapActions.refundable:
          await __updateWalletTxs(swapTx, wallet, emit);

          final swap = await __refundSwap(swapTx, wallet, emit);
          if (swap != null) {
            await __updateWalletTxs(
              swap,
              wallet,
              emit,
            );
          }

        case SubmarineSwapActions.settled:
          final updatedSwapTx = swapTx.copyWith(completionTime: DateTime.now());
          final w = await __updateWalletTxs(
            updatedSwapTx,
            wallet,
            emit,
          );
          if (w == null) break;
          await __closeSwap(updatedSwapTx, emit);
      }
    } else if (swapTx.isChainSwap()) {
      switch (swapTx.chainSwapAction()) {
        case ChainSwapActions.created:
          await __updateWalletTxs(swapTx, wallet, emit);

        case ChainSwapActions.paid:
          if (swapTx.isChainReceive() && swapTx.lockupTxid == null) {
            final (txid, err) = await _swapBoltz.chainUserLockup(
              swapTx: swapTx,
              wallet: wallet,
            );
            if (err != null) {
              await __updateWalletTxs(swapTx, wallet, emit);
            } else {
              await __updateWalletTxs(
                swapTx.copyWith(lockupTxid: txid),
                wallet,
                emit,
              );
            }
          } else {
            await __updateWalletTxs(swapTx, wallet, emit);
          }

        case ChainSwapActions.claimable:
          final swap = await __onChainclaimSwap(swapTx, wallet, emit);
          if (swap != null) {
            await __updateWalletTxs(swap, wallet, emit);
          } else {
            await __updateWalletTxs(swapTx, wallet, emit);
          }

        case ChainSwapActions.settled:
          final updatedSwapTx = swapTx.copyWith(completionTime: DateTime.now());
          await __updateWalletTxs(updatedSwapTx, wallet, emit);

          await __closeSwap(swapTx, emit);

          await _appWalletsRepository
              .getWalletServiceById(
                swapTx.chainSwapDetails!.toWalletId,
              )
              ?.syncWallet();

        case ChainSwapActions.refundable:
          final swap = await __onchainRefund(swapTx, wallet, emit);

          if (swap != null) await __updateWalletTxs(swap, wallet, emit);

        default:
          await __updateWalletTxs(swapTx, wallet, emit);
      }
    }

    await Future.delayed(
      const Duration(
        milliseconds: 1000,
      ),
    );
  }
}
