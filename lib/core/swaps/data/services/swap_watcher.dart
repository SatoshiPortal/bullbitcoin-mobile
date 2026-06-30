import 'dart:async';
import 'dart:math';

import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap_tx_outspend.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bip21_uri/bip21_uri.dart';
import 'package:bull_sdk/boltz.dart' as boltz;

/// Listens to swap status updates and executes the client-side swap actions:
/// claims, refunds and cooperative closes.
class SwapWatcherService {
  final BoltzSwapRepository _boltzRepo;
  final WalletAddressRepository _walletAddressRepository;
  final FeesRepository _feesRepository;

  StreamSubscription<Swap>? _swapStreamSubscription;

  final Map<String, Future<void>> _inflight = {};
  final Map<String, Swap> _queuedNext = {};
  final Map<String, ({int attempts, DateTime nextAttemptAt})> _retrySchedule =
      {};

  static const _actionTimeout = Duration(minutes: 3);
  static const _maxRetryDelay = Duration(minutes: 30);

  /// A websocket can be connected but mute (server-side subscription lost,
  /// half-open TCP that answers protocol pings). While swaps are ongoing,
  /// reconcile their status over REST on a fixed cadence so staleness is
  /// bounded by this interval no matter what the socket claims.
  static const _reconcileInterval = Duration(minutes: 3);
  Timer? _reconcileTimer;
  bool _reconciling = false;

  SwapWatcherService({
    required this._boltzRepo,
    required this._walletAddressRepository,
    required this._feesRepository,
    bool autoStart = true,
  }) {
    if (autoStart) {
      unawaited(startWatching());
    }
  }

  Future<void> startWatching() async {
    await _swapStreamSubscription?.cancel();
    _swapStreamSubscription = _boltzRepo.swapUpdatesStream.listen(
      (swap) async {
        log.fine(
          '[SwapWatcher] update swap=${swap.id} status=${swap.status.name}',
        );
        await processSwap(swap);
      },
      onError: (Object error) {
        log.severe(
          message: 'Swap stream error in watcher',
          error: error,
          trace: StackTrace.current,
        );
      },
      cancelOnError: false,
    );
    _reconcileTimer ??= Timer.periodic(
      _reconcileInterval,
      (_) => unawaited(_reconcileOngoing()),
    );
    log.fine('[SwapWatcher] started and listening');
  }

  Future<void> stopWatching() async {
    _reconcileTimer?.cancel();
    _reconcileTimer = null;
    await _swapStreamSubscription?.cancel();
    _swapStreamSubscription = null;
    log.fine('[SwapWatcher] stopped');
  }

  Future<void> _reconcileOngoing() async {
    if (_reconciling) return;
    _reconciling = true;
    try {
      final swaps = await _boltzRepo.getOngoingSwaps();
      if (swaps.isEmpty) return;
      final ids = swaps.map((s) => s.id).toSet().toList();
      log.fine('[SwapWatcher] heartbeat reconcile of ${ids.length} swaps');
      _boltzRepo.subscribeToSwaps(ids);
      await _boltzRepo.reconcileSwaps(ids);
    } catch (e) {
      log.warning('[SwapWatcher] heartbeat reconcile failed: $e');
    } finally {
      _reconciling = false;
    }
  }

  Future<void> restartWatcherWithOngoingSwaps() async {
    if (_swapStreamSubscription == null) {
      await startWatching();
    }
    final swaps = await _boltzRepo.getOngoingSwaps();
    final swapIdsToWatch = swaps.map((swap) => swap.id).toSet().toList();

    for (final swapId in swapIdsToWatch) {
      _clearRetries(swapId);
    }

    _boltzRepo.subscribeToSwaps(swapIdsToWatch);
    await _boltzRepo.reconcileSwaps(swapIdsToWatch);
  }

  /// Reconciles and processes every ongoing swap to completion. Used by the
  /// background task, which has no long-lived websocket.
  Future<void> processOngoingSwapsOnce() async {
    final swaps = await _boltzRepo.getOngoingSwaps();
    final ids = swaps.map((s) => s.id).toSet().toList();
    await _boltzRepo.reconcileSwaps(ids);
    final refreshed = await _boltzRepo.getOngoingSwaps();
    for (final swap in refreshed) {
      if (swap.requiresAction) {
        await processSwap(swap);
      }
    }
  }

  Future<void> processSwap(Swap swap) {
    final existing = _inflight[swap.id];
    if (existing != null) {
      _queuedNext[swap.id] = swap;
      return existing;
    }

    final future = _processSwapNow(swap).whenComplete(() {
      _inflight.remove(swap.id);
      final next = _queuedNext.remove(swap.id);
      if (next != null) {
        unawaited(processSwap(next));
      }
    });
    _inflight[swap.id] = future;
    return future;
  }

  Future<void> _processSwapNow(Swap incoming) async {
    Swap swap;
    try {
      swap = await _boltzRepo.getSwap(swapId: incoming.id);
    } catch (_) {
      swap = incoming;
    }

    final needsAction = switch (swap.status) {
      SwapStatus.claimable ||
      SwapStatus.refundable ||
      SwapStatus.canCoop ||
      SwapStatus.completed => true,
      _ => false,
    };
    if (!needsAction) return;

    if (!_shouldAttempt(swap.id)) {
      log.fine(
        '[SwapWatcher] swap ${swap.id} backing off until '
        '${_retrySchedule[swap.id]?.nextAttemptAt}',
      );
      return;
    }

    final actionStartedAt = DateTime.now();
    try {
      await _dispatch(swap).timeout(_actionTimeout);
    } on TimeoutException {
      // When the app is suspended mid-action the isolate freezes and the
      // timeout fires immediately on resume — that's not a failure, the
      // thawed action usually completes seconds later. The backoff below is
      // kept either way: it shields the still-running action from a
      // competing attempt.
      final elapsed = DateTime.now().difference(actionStartedAt);
      final wasSuspended = elapsed > _actionTimeout * 2;
      if (wasSuspended) {
        log.info(
          '[SwapWatcher] action for swap ${swap.id} interrupted by app '
          'suspension (${elapsed.inMinutes}m elapsed); it may still '
          'complete now that the app resumed',
        );
      } else {
        log.severe(
          message:
              '[SwapWatcher] action for swap ${swap.id} timed out after '
              '$_actionTimeout',
          error: TimeoutException('swap action timeout'),
          trace: StackTrace.current,
        );
      }
      _recordFailure(swap.id);
      _boltzRepo.subscribeToSwaps([swap.id]);
    } catch (e, st) {
      log.severe(
        message: '[SwapWatcher] error processing swap ${swap.id}',
        error: e,
        trace: st,
      );
      _recordFailure(swap.id);
    }
  }

  Future<void> _dispatch(Swap swap) async {
    switch (swap.status) {
      case SwapStatus.claimable:
        switch (swap.type) {
          case SwapType.lightningToBitcoin:
          case SwapType.lightningToLiquid:
            await _claimLnReceive(swap as LnReceiveSwap);
          case SwapType.liquidToBitcoin:
          case SwapType.bitcoinToLiquid:
            await _claimChain(swap as ChainSwap);
          default:
            return;
        }
      case SwapStatus.refundable:
        switch (swap.type) {
          case SwapType.bitcoinToLightning:
          case SwapType.liquidToLightning:
            await _refundLnSend(swap as LnSendSwap);
          case SwapType.liquidToBitcoin:
          case SwapType.bitcoinToLiquid:
            await _refundChain(swap as ChainSwap);
          default:
            return;
        }
      case SwapStatus.canCoop:
        switch (swap.type) {
          case SwapType.bitcoinToLightning:
          case SwapType.liquidToLightning:
            await _coopCloseSend(swap as LnSendSwap);
          default:
            return;
        }
      case SwapStatus.completed:
        await _processCompletedSwap(swap);
      case SwapStatus.pending:
      case SwapStatus.paid:
      case SwapStatus.refunded:
      case SwapStatus.expired:
      case SwapStatus.failed:
        return;
    }
  }

  // CLAIMS

  Future<void> _claimLnReceive(LnReceiveSwap swap) async {
    if (swap.receiveTxid != null || swap.wasDirectPayment) {
      return;
    }
    // Rescued swaps carry no stored claim address; derive one from the receive
    // wallet (mirrors chain-swap claims and submarine refunds).
    final receiveAddress = await _resolveLnReceiveClaimAddress(swap);
    if (receiveAddress == null) {
      // Keep the swap claimable (funds stay recoverable) but stop hot-looping.
      log.severe(
        message:
            '[SwapWatcher] swap ${swap.id} is claimable but has no receive '
            'address and none could be derived',
        error: StateError('missing receive address'),
        trace: StackTrace.current,
      );
      _recordFailure(swap.id);
      return;
    }

    final isLiquid = swap.type == SwapType.lightningToLiquid;
    final absoluteFees = await _claimFees(
      swap: swap,
      isLiquid: isLiquid,
      amountSat: _amountSatOrNull(swap),
    );
    // Unsubscribe before broadcasting so a status replay can't race the
    // local state write; we re-subscribe on failure.
    _boltzRepo.unsubscribeFromSwaps([swap.id]);

    try {
      String claimTxId;
      try {
        claimTxId = isLiquid
            ? await _boltzRepo.claimLightningToLiquidSwap(
                swapId: swap.id,
                absoluteFees: absoluteFees,
                liquidAddress: receiveAddress,
              )
            : await _boltzRepo.claimLightningToBitcoinSwap(
                swapId: swap.id,
                absoluteFees: absoluteFees,
                bitcoinAddress: receiveAddress,
              );
      } catch (e, st) {
        log.severe(
          message:
              '[SwapWatcher] coop claim failed for ${swap.id} '
              '(${_errorMessage(e)}); trying script path',
          error: e,
          trace: st,
        );
        claimTxId = isLiquid
            ? await _boltzRepo.claimLightningToLiquidSwap(
                swapId: swap.id,
                absoluteFees: absoluteFees,
                liquidAddress: receiveAddress,
                cooperate: false,
              )
            : await _boltzRepo.claimLightningToBitcoinSwap(
                swapId: swap.id,
                absoluteFees: absoluteFees,
                bitcoinAddress: receiveAddress,
                cooperate: false,
              );
      }
      await _finishAction(
        swap,
        isClaim: true,
        txid: claimTxId,
        actualFees: absoluteFees,
      );
    } catch (e, st) {
      await _handleActionFailure(swap, isClaim: true, error: e, trace: st);
    }
  }

  Future<void> _claimChain(ChainSwap swap) async {
    if (swap.receiveTxid != null) {
      return;
    }
    final claimAddress = await _resolveChainClaimAddress(swap);
    if (claimAddress == null) {
      log.severe(
        message:
            '[SwapWatcher] chain swap ${swap.id} is claimable but has '
            'neither a receive wallet nor a receive address',
        error: StateError('missing claim address'),
        trace: StackTrace.current,
      );
      _recordFailure(swap.id);
      return;
    }

    // Claim happens on the receiving chain.
    final claimOnLiquid = swap.type == SwapType.bitcoinToLiquid;
    // Pin the claim fee to the stored creation-time claimFee. An exact-amount
    // external transfer inflates the lockup at creation assuming THIS exact
    // claim fee (see SwapFees.calculateSwapAmountFromReceivableAmount), so a
    // live fee here makes the recipient get more (live < quote) or less
    // (live > quote) than the exact amount — the regression this fixes.
    // Recovered/rescued swaps carry no trustworthy stored claimFee, so they
    // fall back to live estimation (also what keeps the rescue path working).
    // Trade-off accepted for now: a mempool spike above the quote can leave a
    // pinned claim underpriced; revisit with a persisted exact-amount flag.
    final storedClaimFee = swap.fees?.claimFee;
    final absoluteFees = (storedClaimFee != null && storedClaimFee > 0)
        ? storedClaimFee
        : await _claimFees(
            swap: swap,
            isLiquid: claimOnLiquid,
            amountSat: swap.paymentAmount,
            chainClaimAddress: claimAddress,
          );
    _boltzRepo.unsubscribeFromSwaps([swap.id]);

    try {
      String claimTxid;
      try {
        claimTxid = claimOnLiquid
            ? await _boltzRepo.claimBitcoinToLiquidSwap(
                swapId: swap.id,
                absoluteFees: absoluteFees,
                liquidClaimAddress: claimAddress,
              )
            : await _boltzRepo.claimLiquidToBitcoinSwap(
                swapId: swap.id,
                absoluteFees: absoluteFees,
                bitcoinClaimAddress: claimAddress,
              );
      } catch (e, st) {
        log.severe(
          message:
              '[SwapWatcher] coop claim failed for ${swap.id} '
              '(${_errorMessage(e)}); trying script path',
          error: e,
          trace: st,
        );
        claimTxid = claimOnLiquid
            ? await _boltzRepo.claimBitcoinToLiquidSwap(
                swapId: swap.id,
                absoluteFees: absoluteFees,
                liquidClaimAddress: claimAddress,
                cooperate: false,
              )
            : await _boltzRepo.claimLiquidToBitcoinSwap(
                swapId: swap.id,
                absoluteFees: absoluteFees,
                bitcoinClaimAddress: claimAddress,
                cooperate: false,
              );
      }
      await _finishAction(
        swap,
        isClaim: true,
        txid: claimTxid,
        actualFees: absoluteFees,
        claimAddress: claimAddress,
      );
    } catch (e, st) {
      await _handleActionFailure(swap, isClaim: true, error: e, trace: st);
    }
  }

  // REFUNDS

  Future<void> _refundLnSend(LnSendSwap swap) async {
    if (swap.refundTxid != null) {
      return;
    }
    final isLiquid = swap.type == SwapType.liquidToLightning;

    try {
      // Setup (address, fee, tx size) is inside the try so that a failure
      // here — notably boltz's "No user_lock transaction" when a lockup was
      // already spent/pruned — still routes through outspend recovery, which
      // can detect an already-refunded lockup and resolve the swap.
      final refundAddress = await _resolveRefundAddress(
        swap.id,
        swap.sendWalletId,
        swap.refundAddress,
      );
      final networkFee = await _feesRepository.getNetworkFees(
        network: Network.fromEnvironment(isTestnet: false, isLiquid: isLiquid),
      );
      final txSize = await _boltzRepo.getSwapRefundTxSize(
        swapId: swap.id,
        swapType: swap.type,
      );
      var absoluteFees = _absoluteWithFloor(
        networkFee.toAbsolute(txSize).fastest.value.toInt(),
        txSize: txSize,
        isLiquid: isLiquid,
      );
      _boltzRepo.unsubscribeFromSwaps([swap.id]);

      String refundTxid;
      try {
        refundTxid = isLiquid
            ? await _boltzRepo.refundLiquidToLightningSwap(
                swapId: swap.id,
                liquidAddress: refundAddress,
                absoluteFees: absoluteFees,
              )
            : await _boltzRepo.refundBitcoinToLightningSwap(
                swapId: swap.id,
                bitcoinAddress: refundAddress,
                absoluteFees: absoluteFees,
              );
      } catch (e, st) {
        log.severe(
          message:
              '[SwapWatcher] coop refund failed for ${swap.id} '
              '(${_errorMessage(e)}); trying script path',
          error: e,
          trace: st,
        );
        final scriptPathTxSize = await _boltzRepo.getSwapRefundTxSize(
          swapId: swap.id,
          swapType: swap.type,
          isCooperative: false,
        );
        absoluteFees = _absoluteWithFloor(
          networkFee.toAbsolute(scriptPathTxSize).fastest.value.toInt(),
          txSize: scriptPathTxSize,
          isLiquid: isLiquid,
        );
        refundTxid = isLiquid
            ? await _boltzRepo.refundLiquidToLightningSwap(
                swapId: swap.id,
                liquidAddress: refundAddress,
                absoluteFees: absoluteFees,
                cooperate: false,
              )
            : await _boltzRepo.refundBitcoinToLightningSwap(
                swapId: swap.id,
                bitcoinAddress: refundAddress,
                absoluteFees: absoluteFees,
                cooperate: false,
              );
      }
      await _finishAction(
        swap,
        isClaim: false,
        txid: refundTxid,
        actualFees: absoluteFees,
        refundAddress: refundAddress,
      );
    } catch (e, st) {
      await _handleActionFailure(swap, isClaim: false, error: e, trace: st);
    }
  }

  Future<void> _refundChain(ChainSwap swap) async {
    if (swap.refundTxid != null) {
      return;
    }
    // Refund happens on the sending chain.
    final refundOnLiquid = swap.type == SwapType.liquidToBitcoin;

    try {
      // Setup is inside the try so a "No user_lock transaction" failure
      // (lockup already spent/pruned) routes through outspend recovery,
      // which can detect the already-refunded lockup and resolve the swap.
      final refundAddress = await _resolveRefundAddress(
        swap.id,
        swap.sendWalletId,
        swap.refundAddress,
      );
      final networkFee = await _feesRepository.getNetworkFees(
        network: Network.fromEnvironment(
          isTestnet: false,
          isLiquid: refundOnLiquid,
        ),
      );
      final txSize = await _boltzRepo.getSwapRefundTxSize(
        swapId: swap.id,
        swapType: swap.type,
        refundAddressForChainSwaps: refundAddress,
      );
      var absoluteFees = _absoluteWithFloor(
        networkFee.toAbsolute(txSize).fastest.value.toInt(),
        txSize: txSize,
        isLiquid: refundOnLiquid,
      );
      _boltzRepo.unsubscribeFromSwaps([swap.id]);

      String refundTxid;
      try {
        refundTxid = refundOnLiquid
            ? await _boltzRepo.refundLiquidToBitcoinSwap(
                swapId: swap.id,
                absoluteFees: absoluteFees,
                liquidRefundAddress: refundAddress,
              )
            : await _boltzRepo.refundBitcoinToLiquidSwap(
                swapId: swap.id,
                absoluteFees: absoluteFees,
                bitcoinRefundAddress: refundAddress,
              );
      } catch (e, st) {
        log.severe(
          message:
              '[SwapWatcher] coop refund failed for ${swap.id} '
              '(${_errorMessage(e)}); trying script path',
          error: e,
          trace: st,
        );
        final scriptPathTxSize = await _boltzRepo.getSwapRefundTxSize(
          swapId: swap.id,
          swapType: swap.type,
          isCooperative: false,
          refundAddressForChainSwaps: refundAddress,
        );
        absoluteFees = _absoluteWithFloor(
          networkFee.toAbsolute(scriptPathTxSize).fastest.value.toInt(),
          txSize: scriptPathTxSize,
          isLiquid: refundOnLiquid,
        );
        refundTxid = refundOnLiquid
            ? await _boltzRepo.refundLiquidToBitcoinSwap(
                swapId: swap.id,
                absoluteFees: absoluteFees,
                liquidRefundAddress: refundAddress,
                cooperate: false,
              )
            : await _boltzRepo.refundBitcoinToLiquidSwap(
                swapId: swap.id,
                absoluteFees: absoluteFees,
                bitcoinRefundAddress: refundAddress,
                cooperate: false,
              );
      }
      await _finishAction(
        swap,
        isClaim: false,
        txid: refundTxid,
        actualFees: absoluteFees,
        refundAddress: refundAddress,
      );
    } catch (e, st) {
      await _handleActionFailure(swap, isClaim: false, error: e, trace: st);
    }
  }

  // COOP CLOSE

  /// Provides Boltz our key-path signature so it can claim cheaply. A failure
  /// here is not fatal: the payment is already made and the swap completes via
  /// transaction.claimed when Boltz spends script-path (this also covers
  /// batched sub-minimum swaps where no per-swap coop close exists).
  Future<void> _coopCloseSend(LnSendSwap swap) async {
    try {
      if (swap.preimage == null) {
        final preimage = await _boltzRepo.getSendSwapPreimage(swapId: swap.id);
        if (preimage != null) {
          await _boltzRepo.updateSwapFields(swap.id, preimage: preimage);
        }
      }
      if (swap.type == SwapType.bitcoinToLightning) {
        await _boltzRepo.coopSignBitcoinToLightningSwap(swapId: swap.id);
      } else {
        await _boltzRepo.coopSignLiquidToLightningSwap(swapId: swap.id);
      }
      _boltzRepo.unsubscribeFromSwaps([swap.id]);
      _clearRetries(swap.id);
      log.info('[SwapWatcher] coop close succeeded for ${swap.id}');
    } catch (e, st) {
      log.severe(
        message:
            '[SwapWatcher] coop close failed for ${swap.id} '
            '(${_errorMessage(e)}); swap will complete via '
            'transaction.claimed',
        error: e,
        trace: st,
      );
      _recordFailure(swap.id);
    }
  }

  // COMPLETED REPROCESSING

  /// A completed swap without a recorded claim tx means the claim was never
  /// recorded — reopen and re-claim. Direct (MRH) payments are exempt: no
  /// lockup exists and there is nothing to claim.
  Future<void> _processCompletedSwap(Swap swap) async {
    final needsReclaim = switch (swap) {
      LnReceiveSwap(:final receiveTxid, :final wasDirectPayment) =>
        receiveTxid == null && !wasDirectPayment,
      ChainSwap(:final receiveTxid, :final refundTxid) =>
        receiveTxid == null && refundTxid == null,
      LnSendSwap() => false,
    };
    if (!needsReclaim) return;

    final updated = await _boltzRepo.updateSwapFields(
      swap.id,
      status: SwapStatus.claimable,
    );
    unawaited(processSwap(updated));
  }

  // SHARED HELPERS

  /// Live network fees for a claim, computed at execution time from our own
  /// fee estimation (mempool-based), never from the creation-time Boltz
  /// estimate. Falls back to the stored estimate only when live estimation
  /// fails entirely.
  Future<int> _claimFees({
    required Swap swap,
    required bool isLiquid,
    required int? amountSat,
    String? chainClaimAddress,
  }) async {
    Future<int> estimate(bool cooperative) async {
      final txSize = await _boltzRepo.getSwapClaimTxSize(
        swapId: swap.id,
        swapType: swap.type,
        isCooperative: cooperative,
        claimAddressForChainSwaps: chainClaimAddress,
      );
      final networkFee = await _feesRepository.getNetworkFees(
        network: Network.fromEnvironment(isTestnet: false, isLiquid: isLiquid),
      );
      final live = networkFee.toAbsolute(txSize).fastest.value.toInt();
      final withFloor = _absoluteWithFloor(
        live,
        txSize: txSize,
        isLiquid: isLiquid,
      );
      // Never burn more than half the swap on fees, but never drop below the
      // relay floor or the claim tx becomes unbroadcastable.
      if (amountSat != null && amountSat > 0) {
        final floor = _relayFloor(txSize: txSize, isLiquid: isLiquid);
        return max(floor, min(withFloor, max(1, amountSat ~/ 2)));
      }
      return withFloor;
    }

    try {
      return await estimate(true);
    } catch (e) {
      // Cooperative sizing round-trips Boltz and can fail (notably for rescued
      // swaps); the script-path size is computed locally, so try that next.
      try {
        return await estimate(false);
      } catch (e2) {
        final fallback = swap.fees?.claimFee;
        log.warning(
          '[SwapWatcher] live claim fee estimation failed for ${swap.id} '
          '(coop: ${_errorMessage(e)}; script: ${_errorMessage(e2)}); '
          'falling back to stored estimate $fallback',
        );
        if (fallback == null) rethrow;
        return fallback;
      }
    }
  }

  /// Floors an absolute fee at the network's relay minimum so a low estimate
  /// can never produce an unbroadcastable transaction. Liquid floors at
  /// 0.1 sat/vb (plus discount-CT padding), Bitcoin at 1 sat/vb.
  int _relayFloor({required int txSize, required bool isLiquid}) =>
      isLiquid ? (txSize * 0.11).ceil() + 1 : txSize;

  int _absoluteWithFloor(
    int absolute, {
    required int txSize,
    required bool isLiquid,
  }) {
    return max(absolute, _relayFloor(txSize: txSize, isLiquid: isLiquid));
  }

  Future<String?> _resolveLnReceiveClaimAddress(LnReceiveSwap swap) async {
    final existing = swap.receiveAddress;
    if (existing != null) return existing;
    try {
      final claimAddress = await _walletAddressRepository
          .generateNewReceiveAddress(walletId: swap.receiveWalletId);
      await _boltzRepo.updateSwapFields(
        swap.id,
        receiveAddress: claimAddress.address,
      );
      return claimAddress.address;
    } catch (e, st) {
      log.severe(
        message: '[SwapWatcher] could not derive claim address for ${swap.id}',
        error: e,
        trace: st,
      );
      return null;
    }
  }

  Future<String?> _resolveChainClaimAddress(ChainSwap swap) async {
    final existing = swap.receiveAddress;
    if (existing != null) {
      if (existing.startsWith('bitcoin:') ||
          existing.startsWith('liquidnetwork:') ||
          existing.startsWith('liquidtestnet:')) {
        return bip21.decode(existing).address;
      }
      return existing;
    }
    final receiveWalletId = swap.receiveWalletId;
    if (receiveWalletId == null) return null;
    final claimAddress = await _walletAddressRepository
        .generateNewReceiveAddress(walletId: receiveWalletId);
    await _boltzRepo.updateSwapFields(
      swap.id,
      receiveAddress: claimAddress.address,
    );
    return claimAddress.address;
  }

  Future<String> _resolveRefundAddress(
    String swapId,
    String sendWalletId,
    String? existing,
  ) async {
    if (existing != null) return existing;
    final address = await _walletAddressRepository.generateNewReceiveAddress(
      walletId: sendWalletId,
    );
    await _boltzRepo.updateSwapFields(swapId, refundAddress: address.address);
    return address.address;
  }

  Future<void> _finishAction(
    Swap swap, {
    required bool isClaim,
    required String txid,
    required int actualFees,
    String? claimAddress,
    String? refundAddress,
  }) async {
    await _boltzRepo.updateSwapFields(
      swap.id,
      status: isClaim ? SwapStatus.completed : SwapStatus.refunded,
      receiveTxid: isClaim ? txid : null,
      refundTxid: isClaim ? null : txid,
      receiveAddress: claimAddress,
      refundAddress: refundAddress,
      claimFee: isClaim ? actualFees : null,
      refundFee: isClaim ? null : actualFees,
      completionTime: DateTime.now(),
    );
    _clearRetries(swap.id);
    log.info(
      '[SwapWatcher] ${isClaim ? 'claim' : 'refund'} succeeded for '
      '${swap.id} txid=$txid fees=$actualFees',
    );
  }

  Future<void> _handleActionFailure(
    Swap swap, {
    required bool isClaim,
    required Object error,
    required StackTrace trace,
  }) async {
    log.severe(
      message:
          '[SwapWatcher] ${isClaim ? 'claim' : 'refund'} failed for '
          '${swap.id}: ${_errorMessage(error)}',
      error: error,
      trace: trace,
    );

    // A recovered swap whose claim/refund is rejected because the lockup input
    // is already spent ("bad-txns-inputs-missingorspent") was already
    // claimed/refunded before we recovered it — there is nothing left to do and
    // its funds are not at risk. It can never make progress, so delete it
    // instead of leaving it stuck as an ongoing transfer in the list.
    if (swap.recovered && _isAlreadySpentError(error)) {
      log.info(
        '[SwapWatcher] recovered swap ${swap.id} already resolved on-chain '
        '(lockup spent) — deleting stale entry',
      );
      _boltzRepo.unsubscribeFromSwaps([swap.id]);
      await _boltzRepo.deleteSwap(swapId: swap.id);
      return;
    }

    final recovered = await _checkAndRecoverFromOutspend(
      swap: swap,
      isClaim: isClaim,
    );
    if (recovered) return;

    if (!isClaim && _isNonFinalError(error)) {
      // Script-path refunds are only valid after the swap's timelock; stay
      // refundable and retry later.
      log.info(
        '[SwapWatcher] refund for ${swap.id} not yet final (timelock); '
        'will retry',
      );
    }

    _boltzRepo.subscribeToSwaps([swap.id]);
    _recordFailure(swap.id);
  }

  /// Checks whether the relevant lockup output is already spent — meaning an
  /// earlier claim/refund broadcast actually succeeded — and if so records
  /// the spending txid and settles the swap. Read-only and safe to run on
  /// any failure.
  Future<bool> _checkAndRecoverFromOutspend({
    required Swap swap,
    required bool isClaim,
  }) async {
    try {
      final Network network;
      SwapDirection? swapDirection;

      switch (swap) {
        case ChainSwap():
          // Claims spend the server lockup on the receiving chain; refunds
          // spend our own lockup on the sending chain.
          final liquidSide = isClaim
              ? swap.type == SwapType.bitcoinToLiquid
              : swap.type == SwapType.liquidToBitcoin;
          network = Network.fromEnvironment(
            isTestnet: false,
            isLiquid: liquidSide,
          );
          swapDirection = swap.type == SwapType.liquidToBitcoin
              ? SwapDirection.liquidToBitcoin
              : SwapDirection.bitcoinToLiquid;
        case LnReceiveSwap():
          network = Network.fromEnvironment(
            isTestnet: false,
            isLiquid: swap.type == SwapType.lightningToLiquid,
          );
        case LnSendSwap():
          network = Network.fromEnvironment(
            isTestnet: false,
            isLiquid: swap.type == SwapType.liquidToLightning,
          );
      }

      final outspendStatus = await _boltzRepo.checkSwapLockupOutspend(
        swapId: swap.id,
        swapType: swap.type,
        network: network,
        swapDirection: swapDirection,
        isClaim: isClaim,
      );

      final txid = outspendStatus.txid;
      if (txid == null) return false;

      log.info(
        '[SwapWatcher] outspend recovery for ${swap.id}: '
        '${isClaim ? 'claim' : 'refund'} already on-chain as $txid',
      );
      await _boltzRepo.updateSwapFields(
        swap.id,
        status: isClaim ? SwapStatus.completed : SwapStatus.refunded,
        receiveTxid: isClaim ? txid : null,
        refundTxid: isClaim ? null : txid,
        completionTime: outspendStatus.timestamp ?? DateTime.now(),
      );
      _boltzRepo.unsubscribeFromSwaps([swap.id]);
      _clearRetries(swap.id);
      return true;
    } catch (e, st) {
      log.severe(
        message: '[SwapWatcher] outspend check failed for ${swap.id}',
        error: e,
        trace: st,
      );
      return false;
    }
  }

  // RETRY BACKOFF

  bool _shouldAttempt(String swapId) {
    final schedule = _retrySchedule[swapId];
    return schedule == null || DateTime.now().isAfter(schedule.nextAttemptAt);
  }

  void _recordFailure(String swapId) {
    final attempts = (_retrySchedule[swapId]?.attempts ?? 0) + 1;
    final delay = Duration(minutes: min(1 << min(attempts, 5), 30));
    final clamped = delay > _maxRetryDelay ? _maxRetryDelay : delay;
    _retrySchedule[swapId] = (
      attempts: attempts,
      nextAttemptAt: DateTime.now().add(clamped),
    );
    log.info(
      '[SwapWatcher] swap $swapId attempt $attempts failed; next attempt '
      'after $clamped',
    );
  }

  void _clearRetries(String swapId) {
    _retrySchedule.remove(swapId);
  }

  /// The receive amount requires decoding the invoice; a malformed invoice
  /// must never block a claim, so failures just drop the fee cap.
  int? _amountSatOrNull(Swap swap) {
    try {
      return swap.amountSat;
    } catch (_) {
      return null;
    }
  }

  bool _isNonFinalError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('non-final') ||
        message.contains('non_final') ||
        message.contains('nonfinal') ||
        message.contains('non-bip68-final') ||
        message.contains('locktime');
  }

  // Electrum rejects a broadcast whose inputs are already spent with
  // "bad-txns-inputs-missingorspent" (RPC code -25). For a swap lockup that
  // means it was already claimed or refunded.
  bool _isAlreadySpentError(Object error) =>
      _errorMessage(error).toLowerCase().contains('missingorspent');

  String _errorMessage(Object error) {
    if (error is boltz.BoltzError) {
      return error.message;
    }
    return error.toString();
  }
}
