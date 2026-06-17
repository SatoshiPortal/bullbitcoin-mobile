import 'dart:async';
import 'dart:math';

import 'package:bolt11_decoder/bolt11_decoder.dart';
import 'package:bb_mobile/core/swaps/data/datasources/boltz_datasource.dart';
import 'package:bb_mobile/core/swaps/data/models/auto_swap_model.dart';
import 'package:bb_mobile/core/swaps/data/models/swap_model.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap_tx_outspend.dart'
    hide SwapDirection;
import 'package:bb_mobile/core/swaps/domain/entity/swap_tx_outspend.dart'
    as outspend;
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

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
    required String mnemonic,
    required String walletId,
    required int amountSat,
    required String electrumUrl,
    required String claimAddress,
    String? description,
  }) async {
    return _withCreationLock(() async {
      final index = await _nextRevKeyIndex(walletId);
      final btcLnSwap = await _boltz.createBtcReverseSwap(
        walletId: walletId,
        mnemonic: mnemonic,
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
    required String mnemonic,
    required String walletId,
    required int amountSat,
    required String electrumUrl,
    required String claimAddress,
    String? description,
  }) async {
    return _withCreationLock(() async {
      final index = await _nextRevKeyIndex(walletId);
      final lbtcLnSwap = await _boltz.createLBtcReverseSwap(
        walletId: walletId,
        mnemonic: mnemonic,
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
    required String mnemonic,
    required String walletId,
    required String invoice,
    required String electrumUrl,
  }) async {
    return _withCreationLock(() async {
      final index = await _nextSubKeyIndex(walletId);
      final btcLnSwap = await _boltz.createBtcSubmarineSwap(
        walletId: walletId,
        mnemonic: mnemonic,
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
    required String mnemonic,
    required String walletId,
    required String invoice,
    required String electrumUrl,
  }) async {
    return _withCreationLock(() async {
      final index = await _nextSubKeyIndex(walletId);
      final lbtcLnSwap = await _boltz.createLbtcSubmarineSwap(
        walletId: walletId,
        mnemonic: mnemonic,
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
    required String sendWalletMnemonic,
    required String sendWalletId,
    required int amountSat,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
    String? receiveWalletId,
    String? externalRecipientAddress,
  }) async {
    return _withCreationLock(() async {
      final index = await _nextChainKeyIndex(sendWalletId);
      final chainSwap = await _boltz.createBtcToLbtcChainSwap(
        sendWalletId: sendWalletId,
        mnemonic: sendWalletMnemonic,
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
    required String sendWalletMnemonic,
    required String sendWalletId,
    required int amountSat,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
    String? receiveWalletId,
    String? externalRecipientAddress,
  }) async {
    return _withCreationLock(() async {
      final index = await _nextChainKeyIndex(sendWalletId);
      final chainSwap = await _boltz.createLbtcToBtcChainSwap(
        sendWalletId: sendWalletId,
        mnemonic: sendWalletMnemonic,
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

  Future<int> _nextRevKeyIndex(String walletId) async {
    final swaps = await _getRevSwapsForWallet(walletId);
    final nextWalletIndex = swaps.isEmpty
        ? 0
        : swaps.map((swap) => swap.keyIndex).reduce(max) + 1;
    return nextWalletIndex;
  }

  Future<List<Swap>> _getRevSwapsForWallet(String walletId) async {
    return (await _boltz.storage.fetchAll())
        .map((swapModel) => swapModel.toEntity())
        .where(
          (swap) =>
              swap.type == SwapType.lightningToBitcoin ||
              swap.type == SwapType.lightningToLiquid,
        )
        .toList();
  }

  Future<int> _nextSubKeyIndex(String walletId) async {
    final swaps = await _getSubSwapsForWallet(walletId);
    final nextWalletIndex = swaps.isEmpty
        ? 0
        : swaps.map((swap) => swap.keyIndex).reduce(max) + 1;
    return nextWalletIndex;
  }

  Future<List<Swap>> _getSubSwapsForWallet(String walletId) async {
    return (await _boltz.storage.fetchAll())
        .map((swapModel) => swapModel.toEntity())
        .where(
          (swap) =>
              swap.type == SwapType.bitcoinToLightning ||
              swap.type == SwapType.liquidToLightning,
        )
        .toList();
  }

  Future<int> _nextChainKeyIndex(String walletId) async {
    final swaps = await _getChainSwapsForWallet(walletId);
    final nextWalletIndex = swaps.isEmpty
        ? 0
        : swaps.map((swap) => swap.keyIndex).reduce(max) + 1;
    return nextWalletIndex;
  }

  Future<List<Swap>> _getChainSwapsForWallet(String walletId) async {
    return (await _boltz.storage.fetchAll())
        .map((swapModel) => swapModel.toEntity())
        .where(
          (swap) =>
              swap.type == SwapType.bitcoinToLiquid ||
              swap.type == SwapType.liquidToBitcoin,
        )
        .toList();
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
    final (sats, expired, bip21, _) = await _boltz.decodeInvoice(invoice);

    String? description;
    try {
      final bolt11 = Bolt11PaymentRequest(invoice);
      final descTag = bolt11.tags.firstWhere(
        (t) => t.type == 'd',
        orElse: () => throw Exception('No description tag'),
      );
      final raw = descTag.data;
      if (raw is String && raw.trim().isNotEmpty) {
        description = raw.trim();
      }
    } catch (_) {}

    return Invoice(
      sats: sats,
      isExpired: expired,
      magicBip21: bip21,
      description: description,
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
