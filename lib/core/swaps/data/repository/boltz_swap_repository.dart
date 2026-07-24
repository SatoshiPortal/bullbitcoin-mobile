import 'dart:async';

import 'package:bb_mobile/core/swaps/data/datasources/boltz_datasource.dart';
import 'package:bb_mobile/core/swaps/data/models/auto_swap_model.dart';
import 'package:bb_mobile/core/swaps/data/models/swap_model.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/entity/restored_swap.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap_master_key_info.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap_tx_outspend.dart'
    hide SwapDirection;
import 'package:bb_mobile/core/swaps/domain/entity/swap_tx_outspend.dart'
    as outspend;
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bull_sdk/boltz.dart' as boltz;

class BoltzSwapRepository {
  final BoltzDatasource _boltz;
  final bool _isTestnet;

  /// Serializes swap creation so two concurrent creations can never compute
  /// the same key index from a stale table scan.
  Future<void> _creationLock = Future.value();

  BoltzSwapRepository({required this._boltz, required this._isTestnet});

  Future<T> _withCreationLock<T>(Future<T> Function() action) {
    final completer = Completer<void>();
    final previous = _creationLock;
    _creationLock = completer.future;
    return previous
        .catchError((_) {})
        .then((_) => action())
        .whenComplete(completer.complete);
  }

  Stream<Swap> get swapUpdatesStream =>
      _boltz.swapUpdatesStream.map((swapModel) => swapModel.toEntity());

  /// RECEIVE LN TO BTC

  Future<LnReceiveSwap> createLightningToBitcoinSwap({
    required String walletId,
    required int amountSat,
    required String electrumUrl,
    required String claimAddress,
    String? description,
  }) async {
    return _withCreationLock(() async {
      final index = await _reserveSwapKeyIndex(1);
      final btcLnSwap = await _boltz.createBtcReverseSwap(
        walletId: walletId,
        index: index,
        outAmount: amountSat,
        isTestnet: _isTestnet,
        electrumUrl: electrumUrl,
        magicRouteHintAddress: claimAddress,
        description: description,
      );
      return btcLnSwap.toEntity() as LnReceiveSwap;
    });
  }

  Future<String> claimLightningToBitcoinSwap({
    required String swapId,
    required String bitcoinAddress,
    required int absoluteFees,
    bool cooperate = true,
  }) async {
    final txid = await _boltz.claimBtcReverseSwap(
      swapId: swapId,
      claimAddress: bitcoinAddress,
      absoluteFees: absoluteFees,
      tryCooperate: cooperate,
    );

    return await _boltz.broadcastBtcLnSwap(
      swapId: swapId,
      signedTxHex: txid,
      broadcastViaBoltz: false,
    );
  }

  /// RECEIVE LN TO LBTC

  Future<LnReceiveSwap> createLightningToLiquidSwap({
    required String walletId,
    required int amountSat,
    required String electrumUrl,
    required String claimAddress,
    String? description,
  }) async {
    return _withCreationLock(() async {
      final index = await _reserveSwapKeyIndex(1);
      final lbtcLnSwap = await _boltz.createLBtcReverseSwap(
        walletId: walletId,
        index: index,
        outAmount: amountSat,
        isTestnet: _isTestnet,
        electrumUrl: electrumUrl,
        magicRouteHintAddress: claimAddress,
        description: description,
      );

      return lbtcLnSwap.toEntity() as LnReceiveSwap;
    });
  }

  Future<String> claimLightningToLiquidSwap({
    required String swapId,
    required String liquidAddress,
    required int absoluteFees,
    bool cooperate = true,
  }) async {
    final signedTxHex = await _boltz.claimLBtcReverseSwap(
      swapId: swapId,
      claimAddress: liquidAddress,
      absoluteFees: absoluteFees,
      tryCooperate: cooperate,
    );

    return await _boltz.broadcastLbtcLnSwap(
      swapId: swapId,
      signedTxHex: signedTxHex,
      broadcastViaBoltz: false,
    );
  }

  /// SEND BTC TO LN

  Future<LnSendSwap> createBitcoinToLightningSwap({
    required String walletId,
    required String invoice,
    required String electrumUrl,
  }) async {
    return _withCreationLock(() async {
      final index = await _reserveSwapKeyIndex(1);
      final btcLnSwap = await _boltz.createBtcSubmarineSwap(
        walletId: walletId,
        index: index,
        invoice: invoice,
        isTestnet: _isTestnet,
        electrumUrl: electrumUrl,
      );

      return btcLnSwap.toEntity() as LnSendSwap;
    });
  }

  Future<void> coopSignBitcoinToLightningSwap({required String swapId}) async {
    await _boltz.coopSignBtcSubmarineSwap(swapId: swapId);
    await _updateCompletedSendSwap(swapId: swapId);
    return;
  }

  Future<String> refundBitcoinToLightningSwap({
    required String swapId,
    required String bitcoinAddress,
    required int absoluteFees,
    bool cooperate = true,
  }) async {
    final signedTxHex = await _boltz.refundBtcSubmarineSwap(
      swapId: swapId,
      refundAddress: bitcoinAddress,
      absoluteFees: absoluteFees,
      tryCooperate: cooperate,
    );

    return await _boltz.broadcastBtcLnSwap(
      swapId: swapId,
      signedTxHex: signedTxHex,
      broadcastViaBoltz: false,
    );
  }

  /// SEND LBTC TO LN

  Future<LnSendSwap> createLiquidToLightningSwap({
    required String walletId,
    required String invoice,
    required String electrumUrl,
  }) async {
    return _withCreationLock(() async {
      final index = await _reserveSwapKeyIndex(1);
      final lbtcLnSwap = await _boltz.createLbtcSubmarineSwap(
        walletId: walletId,
        index: index,
        invoice: invoice,
        isTestnet: _isTestnet,
        electrumUrl: electrumUrl,
      );

      return lbtcLnSwap.toEntity() as LnSendSwap;
    });
  }

  Future<void> coopSignLiquidToLightningSwap({required String swapId}) async {
    await _boltz.coopSignLbtcSubmarineSwap(swapId: swapId);
    await _updateCompletedSendSwap(swapId: swapId);
    return;
  }

  Future<String> refundLiquidToLightningSwap({
    required String swapId,
    required String liquidAddress,
    required int absoluteFees,
    bool cooperate = true,
  }) async {
    final signedTxHex = await _boltz.refundLbtcSubmarineSwap(
      swapId: swapId,
      refundAddress: liquidAddress,
      absoluteFees: absoluteFees,
      tryCooperate: cooperate,
    );

    return await _boltz.broadcastLbtcLnSwap(
      swapId: swapId,
      signedTxHex: signedTxHex,
      broadcastViaBoltz: false,
    );
  }

  Future<ChainSwap> createBitcoinToLiquidSwap({
    required String sendWalletId,
    required int amountSat,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
    String? receiveWalletId,
    String? externalRecipientAddress,
  }) async {
    return _withCreationLock(() async {
      final index = await _reserveSwapKeyIndex(2);
      final chainSwap = await _boltz.createBtcToLbtcChainSwap(
        sendWalletId: sendWalletId,
        index: index,
        amountSat: amountSat,
        isTestnet: _isTestnet,
        btcElectrumUrl: btcElectrumUrl,
        lbtcElectrumUrl: lbtcElectrumUrl,
        receiveWalletId: receiveWalletId,
        externalRecipientAddress: externalRecipientAddress,
      );

      return chainSwap.toEntity() as ChainSwap;
    });
  }

  Future<ChainSwap> createLiquidToBitcoinSwap({
    required String sendWalletId,
    required int amountSat,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
    String? receiveWalletId,
    String? externalRecipientAddress,
  }) async {
    return _withCreationLock(() async {
      final index = await _reserveSwapKeyIndex(2);
      final chainSwap = await _boltz.createLbtcToBtcChainSwap(
        sendWalletId: sendWalletId,
        index: index,
        amountSat: amountSat,
        isTestnet: _isTestnet,
        btcElectrumUrl: btcElectrumUrl,
        lbtcElectrumUrl: lbtcElectrumUrl,
        receiveWalletId: receiveWalletId,
        externalRecipientAddress: externalRecipientAddress,
      );

      return chainSwap.toEntity() as ChainSwap;
    });
  }

  Future<String> claimLiquidToBitcoinSwap({
    required String swapId,
    required String bitcoinClaimAddress,
    required int absoluteFees,
    bool cooperate = true,
  }) async {
    final signedTxHex = await _boltz.claimLbtcToBtcChainSwap(
      swapId: swapId,
      claimBitcoinAddress: bitcoinClaimAddress,
      absoluteFees: absoluteFees,
      tryCooperate: cooperate,
    );

    return await _boltz.broadcastChainSwapClaim(
      swapId: swapId,
      signedTxHex: signedTxHex,
      broadcastViaBoltz: false,
    );
  }

  Future<String> claimBitcoinToLiquidSwap({
    required String swapId,
    required String liquidClaimAddress,
    required int absoluteFees,
    bool cooperate = true,
  }) async {
    final signedTxHex = await _boltz.claimBtcToLbtcChainSwap(
      swapId: swapId,
      claimLiquidAddress: liquidClaimAddress,
      absoluteFees: absoluteFees,
      tryCooperate: cooperate,
    );

    return await _boltz.broadcastChainSwapClaim(
      swapId: swapId,
      signedTxHex: signedTxHex,
      broadcastViaBoltz: false,
    );
  }

  Future<String> refundBitcoinToLiquidSwap({
    required String swapId,
    required String bitcoinRefundAddress,
    required int absoluteFees,
    bool cooperate = true,
  }) async {
    final signedTxHex = await _boltz.refundBtcToLbtcChainSwap(
      swapId: swapId,
      refundBitcoinAddress: bitcoinRefundAddress,
      absoluteFees: absoluteFees,
      tryCooperate: cooperate,
    );

    return await _boltz.broadcastChainSwapRefund(
      swapId: swapId,
      signedTxHex: signedTxHex,
      broadcastViaBoltz: false,
    );
  }

  Future<String> refundLiquidToBitcoinSwap({
    required String swapId,
    required String liquidRefundAddress,
    required int absoluteFees,
    bool cooperate = true,
  }) async {
    final signedTxHex = await _boltz.refundLbtcToBtcChainSwap(
      swapId: swapId,
      refundLiquidAddress: liquidRefundAddress,
      absoluteFees: absoluteFees,
      tryCooperate: cooperate,
    );

    return await _boltz.broadcastChainSwapRefund(
      swapId: swapId,
      signedTxHex: signedTxHex,
      broadcastViaBoltz: false,
    );
  }

  // STORAGE

  Future<Swap> getSwap({required String swapId}) async {
    final swapModel = await _boltz.storage.fetch(swapId);
    if (swapModel == null) {
      throw "No swap found";
    }
    return swapModel.toEntity();
  }

  /// DB-backed: emits current state on listen + every change, so observers
  /// can't miss a terminal update like the old broadcast stream could.
  Stream<Swap> watchSwap({required String swapId}) =>
      _boltz.storage.watchSwap(swapId).map((model) => model.toEntity());

  Future<void> updatePaidSendSwap({
    required String swapId,
    required String txid,
    int? absoluteFees,
  }) async {
    final swapModel = await _boltz.storage.fetch(swapId);
    if (swapModel == null) {
      throw "No swap model found";
    }

    final swap = swapModel.toEntity();
    // check the status before updating it
    // it is possible that the stream updates the status before this method
    // we don't want a status ahead of paid to be updated back to paid
    final updatedSwap = switch (swap) {
      LnSendSwap() => swap.copyWith(
        sendTxid: txid,
        status: swap.status == SwapStatus.pending
            ? SwapStatus.paid
            : swap.status,
        fees: absoluteFees != null
            ? swap.fees?.copyWith(lockupFee: absoluteFees)
            : swap.fees,
      ),
      ChainSwap() => swap.copyWith(
        sendTxid: txid,
        status: swap.status == SwapStatus.pending
            ? SwapStatus.paid
            : swap.status,
        fees: absoluteFees != null
            ? swap.fees?.copyWith(lockupFee: absoluteFees)
            : swap.fees,
      ),
      _ => throw "Only lnSend or chain swaps can be marked as paid",
    };

    await _boltz.storage.store(SwapModel.fromEntity(updatedSwap));
  }

  Future<Swap> updateSendSwapLockupFees({
    required String swapId,
    required int lockupFees,
  }) async {
    final swapModel = await _boltz.storage.fetch(swapId);
    if (swapModel == null) {
      throw "No swap model found";
    }

    final swap = swapModel.toEntity();
    final updatedSwap = switch (swap) {
      LnSendSwap() => swap.copyWith(
        fees: swap.fees?.copyWith(lockupFee: lockupFees),
      ),
      ChainSwap() => swap.copyWith(
        fees: swap.fees?.copyWith(lockupFee: lockupFees),
      ),
      _ => throw "Only lnSend or chain swaps can have lockup fees updated",
    };

    await _boltz.storage.store(SwapModel.fromEntity(updatedSwap));
    return updatedSwap;
  }

  /// PRIVATE
  Future<void> _updateCompletedSendSwap({required String swapId}) async {
    final swapModel = await _boltz.storage.fetch(swapId);
    if (swapModel == null) {
      throw "No swap model found";
    }

    final swap = swapModel.toEntity();
    if (!(swap.status == SwapStatus.paid ||
        swap.status == SwapStatus.canCoop)) {
      throw "Can only update status of a paid or canCoop swap";
    }

    // Handle each type separately
    final updatedSwap = switch (swap) {
      LnReceiveSwap() =>
        swap.receiveTxid != null
            ? swap.copyWith(
                completionTime: DateTime.now(),
                status: SwapStatus.completed,
              )
            : swap,
      LnSendSwap() => swap.copyWith(
        completionTime: DateTime.now(),
        status: SwapStatus.completed,
      ),
      ChainSwap() =>
        (swap.receiveTxid != null || swap.refundTxid != null)
            ? swap.copyWith(
                completionTime: DateTime.now(),
                status: SwapStatus.completed,
              )
            : swap,
    };

    await _boltz.storage.store(SwapModel.fromEntity(updatedSwap));
  }

  /// Binds the swap master key to [walletFingerprint] for reads and reports
  /// whether it already exists — cheap, so the caller can skip decrypting the
  /// wallet seed when the key is already present.
  Future<bool> swapMasterKeyReady({required String walletFingerprint}) =>
      _boltz.swapMasterKeyReady(
        walletFingerprint: walletFingerprint,
        isTestnet: _isTestnet,
      );

  /// Derives + persists the swap master key from the default wallet's seed.
  /// Called once, only when [swapMasterKeyReady] reported a miss, so swap
  /// creation and restore can READ the key from storage and never derive lazily.
  Future<void> deriveSwapMasterKey({
    required String mnemonic,
    required String walletFingerprint,
  }) => _boltz.deriveSwapMasterKey(
    mnemonic: mnemonic,
    walletFingerprint: walletFingerprint,
    isTestnet: _isTestnet,
  );

  /// Reads the swap master key (the "swap mnemonic") for [walletFingerprint]
  /// for display/management in the seed viewer. Null when none is stored.
  Future<SwapMasterKeyInfo?> getSwapMasterKeyInfo({
    required String walletFingerprint,
  }) async {
    final model = await _boltz.getSwapMasterKeyForWallet(
      walletFingerprint: walletFingerprint,
      isTestnet: _isTestnet,
    );
    if (model == null) return null;
    return SwapMasterKeyInfo(
      mnemonic: model.mnemonic,
      fingerprint: model.fingerprint,
      walletFingerprint: walletFingerprint,
      network: model.network,
    );
  }

  /// Deletes the swap master key (and its index counter) for
  /// [walletFingerprint]. Super-user action; the next ensure re-derives it.
  Future<void> deleteSwapMasterKey({required String walletFingerprint}) =>
      _boltz.deleteSwapMasterKey(
        walletFingerprint: walletFingerprint,
        isTestnet: _isTestnet,
      );

  // Reverse and submarine swaps consume 1 index; chain swaps consume 2 (boltz
  // derives the refund key at `index` and the claim key at `index + 1`).
  Future<int> _reserveSwapKeyIndex(int count) async {
    final swapMasterKey = await _boltz.getSwapMasterKey(isTestnet: _isTestnet);
    // The index counter is keyed by the swap master key's OWN fingerprint —
    // NOT the default wallet's fingerprint (which keys the master key blob).
    // Both are 1:1 with the seed, so they stay consistent.
    final stored = await _boltz.storage.getSwapKeyIndex(
      swapMasterKey.fingerprint,
    );
    final int current;
    if (stored == null) {
      // Seed past boltz's highest known index (-1 when none) so a new swap
      // can't re-derive an in-use key on a recovered seed.
      final highest = await _boltz.restoreSwapIndex(
        swapMasterKey: swapMasterKey,
      );
      current = highest + 1;
    } else {
      current = stored;
    }
    await _boltz.storage.setSwapKeyIndex(
      swapMasterKey.fingerprint,
      current + count,
    );
    // The swap master key's fingerprint is deliberately omitted: it is a
    // stable per-wallet identifier derived from the seed and must not
    // appear in logs, which can be shared to support or forwarded to
    // Sentry breadcrumbs.
    log.info('SWAP_KEY: reserved index $current (count=$count)');
    return current;
  }

  /// Removes a swap entirely — local row + secure blob. Used when a recovered
  /// swap is found to be already resolved on-chain (its lockup is already
  /// spent), so it must not keep lingering in the transaction list.
  Future<void> deleteSwap({required String swapId}) async {
    await _boltz.storage.trash(swapId);
    await _boltz.storage.deleteFromSecureStorage(swapId);
  }

  Future<void> updateSwap({required Swap swap}) {
    return _boltz.storage.store(SwapModel.fromEntity(swap));
  }

  /// Single write path for the watcher: re-fetches the stored swap and
  /// merges only the given fields, so a concurrent write (preimage, lockup
  /// fees, sendTxid) is never clobbered by a stale in-memory copy.
  Future<Swap> updateSwapFields(
    String swapId, {
    SwapStatus? status,
    String? receiveTxid,
    String? refundTxid,
    String? receiveAddress,
    String? refundAddress,
    String? preimage,
    int? claimFee,
    int? refundFee,
    DateTime? completionTime,
  }) async {
    final swapModel = await _boltz.storage.fetch(swapId);
    if (swapModel == null) {
      throw 'No swap model found';
    }
    final swap = swapModel.toEntity();
    final fees = (swap.fees ?? const SwapFees()).copyWith(
      claimFee: claimFee ?? swap.fees?.claimFee,
      refundFee: refundFee ?? swap.fees?.refundFee,
    );

    final updated = switch (swap) {
      LnReceiveSwap() => swap.copyWith(
        status: status ?? swap.status,
        receiveTxid: receiveTxid ?? swap.receiveTxid,
        receiveAddress: receiveAddress ?? swap.receiveAddress,
        completionTime: completionTime ?? swap.completionTime,
        fees: fees,
      ),
      LnSendSwap() => swap.copyWith(
        status: status ?? swap.status,
        refundTxid: refundTxid ?? swap.refundTxid,
        refundAddress: refundAddress ?? swap.refundAddress,
        preimage: preimage ?? swap.preimage,
        completionTime: completionTime ?? swap.completionTime,
        fees: fees,
      ),
      ChainSwap() => swap.copyWith(
        status: status ?? swap.status,
        receiveTxid: receiveTxid ?? swap.receiveTxid,
        refundTxid: refundTxid ?? swap.refundTxid,
        receiveAddress: receiveAddress ?? swap.receiveAddress,
        refundAddress: refundAddress ?? swap.refundAddress,
        completionTime: completionTime ?? swap.completionTime,
        fees: fees,
      ),
    };

    await _boltz.storage.store(SwapModel.fromEntity(updated));
    return updated;
  }

  Future<int> getSwapClaimTxSize({
    required String swapId,
    required SwapType swapType,
    bool isCooperative = true,
    String? claimAddressForChainSwaps,
  }) async {
    switch (swapType) {
      case SwapType.lightningToBitcoin:
        return await _boltz.getBtcLnClaimTxSize(
          swapId: swapId,
          isCooperative: isCooperative,
        );
      case SwapType.lightningToLiquid:
        return await _boltz.getLbtcLnClaimTxSize(
          swapId: swapId,
          isCooperative: isCooperative,
        );
      case SwapType.liquidToBitcoin:
      case SwapType.bitcoinToLiquid:
        return await _boltz.getChainClaimTxSize(
          swapId: swapId,
          claimAddress: claimAddressForChainSwaps!,
          isCooperative: isCooperative,
        );
      case SwapType.bitcoinToLightning:
      case SwapType.liquidToLightning:
        throw Exception('Submarine swaps have no claim transaction');
    }
  }

  /// Polls each swap's current status over REST and routes it through the
  /// same status pipeline as websocket events.
  Future<void> reconcileSwaps(List<String> swapIds) =>
      _boltz.reconcileSwaps(swapIds);

  /// Update claimFee to a specific value
  Future<void> updateClaimFee({
    required String swapId,
    required int claimFee,
  }) async {
    final swapModel = await _boltz.storage.fetch(swapId);
    if (swapModel == null) {
      throw "No swap model found";
    }

    final swap = swapModel.toEntity();
    final updatedSwap = swap.copyWith(
      fees: swap.fees?.copyWith(claimFee: claimFee),
    );

    await _boltz.storage.store(SwapModel.fromEntity(updatedSwap));
  }

  /// Update lockupFee to a specific value
  Future<void> updateLockupFee({
    required String swapId,
    required int lockupFee,
  }) async {
    final swapModel = await _boltz.storage.fetch(swapId);
    if (swapModel == null) {
      throw "No swap model found";
    }

    final swap = swapModel.toEntity();
    final updatedSwap = swap.copyWith(
      fees: swap.fees?.copyWith(lockupFee: lockupFee),
    );

    await _boltz.storage.store(SwapModel.fromEntity(updatedSwap));
  }

  void unsubscribeFromSwaps(List<String> swapIds) {
    _boltz.unsubscribeToSwaps(swapIds);
  }

  void subscribeToSwaps(List<String> swapIds) {
    _boltz.subscribeToSwaps(swapIds);
  }

  Future<List<Swap>> getOngoingSwaps({String? walletId}) async {
    final allSwapModels = await _boltz.storage.fetchAll(isTestnet: _isTestnet);

    final allSwaps = allSwapModels
        .map((swapModel) => swapModel.toEntity())
        .toList();
    bool needsWatching(Swap swap) {
      switch (swap.status) {
        case SwapStatus.pending:
        case SwapStatus.paid:
        case SwapStatus.canCoop:
        case SwapStatus.claimable:
        case SwapStatus.refundable:
          return true;
        case SwapStatus.completed:
          // Completed without a recorded claim tx means the claim never
          // happened (unless it was an MRH direct payment with no lockup).
          if (swap is LnReceiveSwap) {
            return swap.receiveTxid == null && !swap.wasDirectPayment;
          }
          if (swap is ChainSwap) {
            return swap.receiveTxid == null && swap.refundTxid == null;
          }
          return false;
        case SwapStatus.expired:
        case SwapStatus.failed:
          // Funds locked and never refunded: keep watching so the swap can
          // become refundable instead of stranding the funds.
          if (swap is LnSendSwap) {
            return swap.sendTxid != null && swap.refundTxid == null;
          }
          if (swap is ChainSwap) {
            return swap.sendTxid != null && swap.refundTxid == null;
          }
          return false;
        case SwapStatus.refunded:
          return false;
      }
    }

    return allSwaps
        .where(
          (swap) =>
              (walletId == null ||
                  swap.walletId == walletId ||
                  swap is ChainSwap && swap.receiveWalletId == walletId) &&
              needsWatching(swap),
        )
        .toList();
  }

  Future<List<Swap>> getAllSwaps({String? walletId}) async {
    final allSwapModels = await _boltz.storage.fetchAll(
      walletId: walletId,
      isTestnet: _isTestnet,
    );
    final allSwaps = allSwapModels
        .map((swapModel) => swapModel.toEntity())
        .toList();
    return allSwaps;
  }

  /// Restores all swaps derivable from the dedicated swap master key via Boltz,
  /// across BTC-LN, LBTC-LN and chain. Identification only (Phase 1); importing
  /// them into local storage is handled separately.
  Future<List<RestoredSwap>> restoreSwaps({required bool isTestnet}) async {
    final swapMasterKey = await _boltz.getSwapMasterKey(isTestnet: isTestnet);
    log.info(
      'SWAP_RESTORE: master key ${swapMasterKey.fingerprint} '
      '(${swapMasterKey.network})',
    );
    final summaries = await _boltz.restoreSwapSummaries(
      swapMasterKey: swapMasterKey,
    );
    log.info('SWAP_RESTORE: restore endpoint returned ${summaries.length}');
    return [
      for (final s in summaries)
        RestoredSwap(
          id: s.id,
          kind: _restoredKind(s.kind),
          status: _restoreStatusToSwapStatus(s.status),
          recoverable: s.recoverable,
          amountSat: s.amount.toInt(),
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            s.createdAt.toInt() * 1000,
          ),
          fromAsset: s.from,
          toAsset: s.to,
        ),
    ];
  }

  // Submarine = on-chain → Lightning (Lightning Send); Reverse = Lightning →
  // on-chain (Lightning Receive); Chain = cross-chain.
  RestoredSwapKind _restoredKind(boltz.SwapType kind) => switch (kind) {
    boltz.SwapType.submarine => RestoredSwapKind.lightningSend,
    boltz.SwapType.reverse => RestoredSwapKind.lightningReceive,
    boltz.SwapType.chain => RestoredSwapKind.crossChain,
  };

  // Coarse mapping of the raw boltz status to the app's status for list display.
  // The rescue flow reconciles the precise per-type state (e.g. a chain
  // `transaction.claimed` where the user's own claim is still pending).
  SwapStatus _restoreStatusToSwapStatus(String boltzStatus) {
    switch (boltzStatus) {
      case 'transaction.claimed':
      case 'invoice.settled':
      case 'transaction.direct':
        return SwapStatus.completed;
      case 'swap.refunded':
      case 'transaction.refunded':
        return SwapStatus.refunded;
      case 'swap.expired':
      case 'invoice.expired':
        return SwapStatus.expired;
      case 'transaction.lockupFailed':
      case 'transaction.failed':
      case 'invoice.failedToPay':
      case 'swap.error':
        return SwapStatus.failed;
      case 'transaction.mempool':
      case 'transaction.confirmed':
      case 'transaction.server.mempool':
      case 'transaction.server.confirmed':
      case 'transaction.claim.pending':
      case 'invoice.paid':
        return SwapStatus.claimable;
      default:
        return SwapStatus.pending;
    }
  }

  // Whether an LN swap's on-chain leg is Liquid (vs Bitcoin). Boltz labels pure
  // BTC lightning swaps "BTC"->"BTC"; anything else involves L-BTC.
  bool _lnSwapIsLiquid(RestoredSwap r) =>
      !(r.fromAsset == 'BTC' && r.toAsset == 'BTC');

  /// Rebuilds a restored swap's full object from Boltz, persists it (secure
  /// blob + local row) under the given wallets, and hands it to the watcher so
  /// an orphaned claim/refund can be completed. [sendWalletId] funds the
  /// lockup/refund side; [receiveWalletId] receives the claim (required for
  /// reverse, optional for chain).
  Future<Swap> rescueSwap({
    required RestoredSwap restored,
    required String sendWalletId,
    String? receiveWalletId,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
  }) async {
    final swapMasterKey = await _boltz.getSwapMasterKey(isTestnet: _isTestnet);
    final creationTime = restored.createdAt.millisecondsSinceEpoch;
    // A refund-action swap with funds still locked on-chain is stored as
    // refundable (not the terminal failed/expired/refunded the restore status
    // maps to) so the watcher actually drives the refund. If the lockup turns
    // out to be already gone the refund attempt resolves it terminally.
    // Only submarine and chain swaps are user-refundable; a reverse swap is
    // claimed, never refunded, and the watcher has no refundable action for it.
    final isUserRefundable =
        restored.kind == RestoredSwapKind.lightningSend ||
        restored.kind == RestoredSwapKind.crossChain;
    final status =
        isUserRefundable && restored.recoverable && restored.isRefundAction
        ? SwapStatus.refundable.name
        : restored.status.name;
    final id = restored.id;
    final isLiquid = _lnSwapIsLiquid(restored);

    final SwapModel model;
    switch (restored.kind) {
      case RestoredSwapKind.lightningReceive:
        if (isLiquid) {
          final swaps = await _boltz.restoreLbtcLnSwaps(
            swapMasterKey: swapMasterKey,
            electrumUrl: lbtcElectrumUrl,
          );
          final obj = swaps.firstWhere(
            (s) => s.id == id,
            orElse: () =>
                throw 'swap $id not returned by boltz restore (possibly beyond gap limit)',
          );
          await _boltz.storage.storeLbtcLnSwap(obj);
          model = SwapModel.lnReceive(
            id: obj.id,
            type: SwapType.lightningToLiquid.name,
            recovered: true,
            boltzFees: await _recoveredBoltzFee(
              SwapType.lightningToLiquid,
              obj.outAmount.toInt(),
            ),
            status: status,
            isTestnet: _isTestnet,
            keyIndex: obj.keyIndex.toInt(),
            creationTime: creationTime,
            receiveWalletId: receiveWalletId!,
            invoice: obj.invoice,
          );
        } else {
          final swaps = await _boltz.restoreBtcLnSwaps(
            swapMasterKey: swapMasterKey,
            electrumUrl: btcElectrumUrl,
          );
          final obj = swaps.firstWhere(
            (s) => s.id == id,
            orElse: () =>
                throw 'swap $id not returned by boltz restore (possibly beyond gap limit)',
          );
          await _boltz.storage.storeBtcLnSwap(obj);
          model = SwapModel.lnReceive(
            id: obj.id,
            type: SwapType.lightningToBitcoin.name,
            recovered: true,
            boltzFees: await _recoveredBoltzFee(
              SwapType.lightningToBitcoin,
              obj.outAmount.toInt(),
            ),
            status: status,
            isTestnet: _isTestnet,
            keyIndex: obj.keyIndex.toInt(),
            creationTime: creationTime,
            receiveWalletId: receiveWalletId!,
            invoice: obj.invoice,
          );
        }
      case RestoredSwapKind.lightningSend:
        if (isLiquid) {
          final swaps = await _boltz.restoreLbtcLnSwaps(
            swapMasterKey: swapMasterKey,
            electrumUrl: lbtcElectrumUrl,
          );
          final obj = swaps.firstWhere(
            (s) => s.id == id,
            orElse: () =>
                throw 'swap $id not returned by boltz restore (possibly beyond gap limit)',
          );
          await _boltz.storage.storeLbtcLnSwap(obj);
          model = SwapModel.lnSend(
            id: obj.id,
            type: SwapType.liquidToLightning.name,
            recovered: true,
            boltzFees: await _recoveredBoltzFee(
              SwapType.liquidToLightning,
              obj.outAmount.toInt(),
            ),
            status: status,
            isTestnet: _isTestnet,
            keyIndex: obj.keyIndex.toInt(),
            creationTime: creationTime,
            sendWalletId: sendWalletId,
            invoice: obj.invoice,
            paymentAddress: obj.scriptAddress,
            paymentAmount: obj.outAmount.toInt(),
          );
        } else {
          final swaps = await _boltz.restoreBtcLnSwaps(
            swapMasterKey: swapMasterKey,
            electrumUrl: btcElectrumUrl,
          );
          final obj = swaps.firstWhere(
            (s) => s.id == id,
            orElse: () =>
                throw 'swap $id not returned by boltz restore (possibly beyond gap limit)',
          );
          await _boltz.storage.storeBtcLnSwap(obj);
          model = SwapModel.lnSend(
            id: obj.id,
            type: SwapType.bitcoinToLightning.name,
            recovered: true,
            boltzFees: await _recoveredBoltzFee(
              SwapType.bitcoinToLightning,
              obj.outAmount.toInt(),
            ),
            status: status,
            isTestnet: _isTestnet,
            keyIndex: obj.keyIndex.toInt(),
            creationTime: creationTime,
            sendWalletId: sendWalletId,
            invoice: obj.invoice,
            paymentAddress: obj.scriptAddress,
            paymentAmount: obj.outAmount.toInt(),
          );
        }
      case RestoredSwapKind.crossChain:
        final swaps = await _boltz.restoreChainSwaps(
          swapMasterKey: swapMasterKey,
          btcElectrumUrl: btcElectrumUrl,
          lbtcElectrumUrl: lbtcElectrumUrl,
        );
        final obj = swaps.firstWhere(
          (s) => s.id == id,
          orElse: () =>
              throw 'swap $id not returned by boltz restore (possibly beyond gap limit)',
        );
        await _boltz.storage.storeChainSwap(obj);
        final lockupTxid = await _boltz.chainSwapUserLockupTxid(obj);
        model = SwapModel.chain(
          id: obj.id,
          type: restored.fromAsset == 'BTC'
              ? SwapType.bitcoinToLiquid.name
              : SwapType.liquidToBitcoin.name,
          recovered: true,
          boltzFees: await _recoveredBoltzFee(
            restored.fromAsset == 'BTC'
                ? SwapType.bitcoinToLiquid
                : SwapType.liquidToBitcoin,
            obj.outAmount.toInt(),
          ),
          status: status,
          isTestnet: _isTestnet,
          keyIndex: obj.refundIndex.toInt(),
          creationTime: creationTime,
          sendWalletId: sendWalletId,
          receiveWalletId: receiveWalletId,
          sendTxid: lockupTxid,
          paymentAddress: obj.scriptAddress,
          paymentAmount: obj.outAmount.toInt(),
        );
    }

    await _boltz.storage.store(model);
    subscribeToSwaps([id]);
    await reconcileSwaps([id]);
    log.info('SWAP_RESTORE: rescued $id as ${model.runtimeType}');
    return model.toEntity();
  }

  /// Boltz's percentage service fee is stable, so for a recovered swap we
  /// recompute it from the live fees (rate × amount) rather than guess. Miner /
  /// network fees are NOT recomputed here — they're derived in the UI from the
  /// actual on-chain sent/received amounts. Returns null if the rate is
  /// unavailable (the swap is still rescued; the fee row is just hidden).
  Future<int?> _recoveredBoltzFee(SwapType type, int amount) async {
    try {
      final fees = await _boltz.getSwapFees(type);
      if (fees.boltzPercent == null) return null;
      return fees.boltzFeeFromPercent(amount);
    } catch (_) {
      return null;
    }
  }

  Future<Swap?> getSwapByTxId(String txId) async {
    final swapModel = await _boltz.storage.fetchByTxId(txId);
    if (swapModel == null) {
      return null; // No swap found for the given txId
    }
    return swapModel.toEntity();
  }

  Future<(SwapLimits, SwapFees)> getSwapLimitsAndFees(SwapType type) async {
    switch (type) {
      case SwapType.lightningToBitcoin:
        final (min, max) = await _boltz.getBtcReverseSwapLimits();
        final fees = await _boltz.getSwapFees(type);
        return (SwapLimits(min: min, max: max), fees);
      case SwapType.lightningToLiquid:
        final (min, max) = await _boltz.getLbtcReverseSwapLimits();
        final fees = await _boltz.getSwapFees(type);
        return (SwapLimits(min: min, max: max), fees);
      case SwapType.liquidToLightning:
        final (min, max) = await _boltz.getLbtcSubmarineSwapLimits();
        final fees = await _boltz.getSwapFees(type);
        return (SwapLimits(min: min, max: max), fees);
      case SwapType.bitcoinToLightning:
        final (min, max) = await _boltz.getBtcSubmarineSwapLimits();
        final fees = await _boltz.getSwapFees(type);
        return (SwapLimits(min: min, max: max), fees);
      case SwapType.liquidToBitcoin:
        final (min, max) = await _boltz.getLbtcToBtcChainSwapLimits();
        final fees = await _boltz.getSwapFees(type);
        return (SwapLimits(min: min, max: max), fees);
      case SwapType.bitcoinToLiquid:
        final (min, max) = await _boltz.getBtcToLbtcChainSwapLimits();
        final fees = await _boltz.getSwapFees(type);
        return (SwapLimits(min: min, max: max), fees);
    }
  }

  Future<void> updateSwapLimitsAndFees(SwapType type) async {
    await _boltz.updateFees(swapType: type);
  }

  Future<Invoice> decodeInvoice({required String invoice}) async {
    final (sats, expired, bip21, description) = await _boltz.decodeInvoice(
      invoice,
    );
    return Invoice(
      sats: sats,
      isExpired: expired,
      magicBip21: bip21,
      description: (description != null && description.trim().isNotEmpty)
          ? description.trim()
          : null,
    );
  }

  Future<LnSendSwap?> getSendSwapByInvoice({required String invoice}) async {
    final allSwaps = await _boltz.storage.fetchAll();
    for (final swapModel in allSwaps) {
      final swap = swapModel.toEntity();
      if (swap.type == SwapType.lightningToBitcoin ||
          swap.type == SwapType.lightningToLiquid) {
        continue;
      }
      if (swap is LnSendSwap &&
          swap.invoice.toLowerCase() == invoice.toLowerCase() &&
          (swap.status == SwapStatus.pending)) {
        return swap;
      }
    }
    return null;
  }

  Future<int> getSwapRefundTxSize({
    required String swapId,
    required SwapType swapType,
    bool isCooperative = true,
    String? refundAddressForChainSwaps,
  }) async {
    switch (swapType) {
      case SwapType.lightningToBitcoin:
        return 0;
      case SwapType.lightningToLiquid:
        return 0;
      case SwapType.liquidToLightning:
        return await _boltz.getLbtLnRefundTxSize(
          swapId: swapId,
          isCooperative: isCooperative,
        );
      case SwapType.bitcoinToLightning:
        return await _boltz.getBtcLnRefundTxSize(
          swapId: swapId,
          isCooperative: isCooperative,
        );
      case SwapType.liquidToBitcoin:
      case SwapType.bitcoinToLiquid:
        return await _boltz.getChainRefundTxSize(
          swapId: swapId,
          isCooperative: isCooperative,
          refundAddress: refundAddressForChainSwaps!,
        );
    }
  }

  Future<String?> getSendSwapPreimage({required String swapId}) async {
    final swap = await getSwap(swapId: swapId);
    if (swap is! LnSendSwap) {
      throw Exception('Swap is not a send swap');
    }
    switch (swap.type) {
      case SwapType.bitcoinToLightning:
        return await _boltz.getBtcLnSwapPreimage(swapId: swapId);
      case SwapType.liquidToLightning:
        return await _boltz.getLbtcLnSwapPreimage(swapId: swapId);
      default:
        throw Exception('Swap type does not support preimage');
    }
  }

  Future<void> migrateOldSwap({
    required String primaryWalletId,
    required String swapId,
    required SwapType swapType,
    required String? lockupTxid,
    required String? counterWalletId,
    required bool? isCounterWalletExternal,
    required String? claimAddress,
  }) async {
    switch (swapType) {
      case SwapType.lightningToBitcoin:
        final swapObject = await _boltz.storage.fetchBtcLnSwap(swapId);
        await _boltz.fromBtcLnSwapObjectMigration(
          swapObject,
          primaryWalletId,
          null,
          lockupTxid,
          claimAddress,
        );
      case SwapType.bitcoinToLightning:
        final swapObject = await _boltz.storage.fetchBtcLnSwap(swapId);
        await _boltz.fromBtcLnSwapObjectMigration(
          swapObject,
          null,
          primaryWalletId,
          lockupTxid,
          null,
        );
      case SwapType.lightningToLiquid:
        final swapObject = await _boltz.storage.fetchLbtcLnSwap(swapId);
        await _boltz.fromLbtcLnSwapObjectMigration(
          swapObject,
          primaryWalletId,
          null,
          lockupTxid,
          claimAddress,
        );
      case SwapType.liquidToLightning:
        final swapObject = await _boltz.storage.fetchLbtcLnSwap(swapId);
        await _boltz.fromLbtcLnSwapObjectMigration(
          swapObject,
          null,
          primaryWalletId,
          lockupTxid,
          null,
        );
      case SwapType.liquidToBitcoin:
        final swapObject = await _boltz.storage.fetchChainSwap(swapId);
        if (counterWalletId == null || isCounterWalletExternal == null) {
          throw Exception(
            'Counter wallet ID and isCounterWalletExternal must be provided for chain swaps',
          );
        }
        await _boltz.fromChainSwapObjectMigration(
          swapObject,
          primaryWalletId,
          counterWalletId,
          isCounterWalletExternal,
          lockupTxid,
        );

      case SwapType.bitcoinToLiquid:
        if (counterWalletId == null || isCounterWalletExternal == null) {
          throw Exception(
            'Counter wallet ID and isCounterWalletExternal must be provided for chain swaps',
          );
        }
        final swapObject = await _boltz.storage.fetchChainSwap(swapId);
        await _boltz.fromChainSwapObjectMigration(
          swapObject,
          primaryWalletId,
          counterWalletId,
          isCounterWalletExternal,
          lockupTxid,
        );
    }
  }

  Future<AutoSwap> getAutoSwapParams() async {
    final model = _isTestnet
        ? await _boltz.storage.getAutoSwapSettingsTestnet()
        : await _boltz.storage.getAutoSwapSettings();
    return model.toEntity();
  }

  Future<void> updateAutoSwapParams(AutoSwap params) async {
    final model = AutoSwapModel.fromEntity(params);
    if (_isTestnet) {
      await _boltz.storage.storeAutoSwapSettingsTestnet(model);
    } else {
      await _boltz.storage.storeAutoSwapSettings(model);
    }
  }

  /// Checks the outspend status of a swap's lockup transaction
  Future<SwapTxOutspend> checkSwapLockupOutspend({
    required String swapId,
    required SwapType swapType,
    required Network network,
    outspend.SwapDirection? swapDirection,
    bool isClaim = true,
  }) async {
    final model = await _boltz.checkSwapLockupOutspend(
      swapId: swapId,
      swapType: swapType,
      network: network,
      swapDirection: swapDirection,
      isClaim: isClaim,
    );
    return model.toEntity();
  }
}
