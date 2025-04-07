import 'dart:async';
import 'dart:math';

import 'package:bb_mobile/core/swaps/data/datasources/boltz_datasource.dart';
import 'package:bb_mobile/core/swaps/data/models/swap_model.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';

class BoltzSwapRepositoryImpl implements SwapRepository {
  final BoltzDatasource _boltz;

  BoltzSwapRepositoryImpl({
    required BoltzDatasource boltz,
  }) : _boltz = boltz;

  @override
  Stream<Swap> get swapUpdatesStream => _boltz.swapUpdatesStream.map(
        (swapModel) => swapModel.toEntity(),
      );

  /// RECEIVE LN TO BTC
  @override
  Future<LnReceiveSwap> createLightningToBitcoinSwap({
    required String mnemonic,
    required String walletId,
    required int amountSat,
    required bool isTestnet,
    required String electrumUrl,
    required String claimAddress,
    String? description,
  }) async {
    final index = await _nextRevKeyIndex(walletId);
    final btcLnSwap = await _boltz.createBtcReverseSwap(
      walletId: walletId,
      mnemonic: mnemonic,
      index: index,
      outAmount: amountSat,
      isTestnet: isTestnet,
      electrumUrl: electrumUrl,
      magicRouteHintAddress: claimAddress,
      description: description,
    );
    return btcLnSwap.toEntity() as LnReceiveSwap;
  }

  @override
  Future<String> claimLightningToBitcoinSwap({
    required String swapId,
    required String bitcoinAddress,
    required int absoluteFees,
  }) async {
    final txid = await _boltz.claimBtcReverseSwap(
      swapId: swapId,
      claimAddress: bitcoinAddress,
      absoluteFees: absoluteFees,
      tryCooperate: true,
    );

    return await _boltz.broadcastBtcLnSwap(
      swapId: swapId,
      signedTxHex: txid,
      broadcastViaBoltz: false,
    );
  }

  /// RECEIVE LN TO LBTC
  @override
  Future<LnReceiveSwap> createLightningToLiquidSwap({
    required String mnemonic,
    required String walletId,
    required int amountSat,
    required bool isTestnet,
    required String electrumUrl,
    required String claimAddress,
    String? description,
  }) async {
    final index = await _nextRevKeyIndex(walletId);
    final lbtcLnSwap = await _boltz.createLBtcReverseSwap(
      walletId: walletId,
      mnemonic: mnemonic,
      index: index,
      outAmount: amountSat,
      isTestnet: isTestnet,
      electrumUrl: electrumUrl,
      magicRouteHintAddress: claimAddress,
      description: description,
    );

    return lbtcLnSwap.toEntity() as LnReceiveSwap;
  }

  @override
  Future<String> claimLightningToLiquidSwap({
    required String swapId,
    required String liquidAddress,
    required int absoluteFees,
  }) async {
    final signedTxHex = await _boltz.claimLBtcReverseSwap(
      swapId: swapId,
      claimAddress: liquidAddress,
      absoluteFees: absoluteFees,
      tryCooperate: true,
    );

    return await _boltz.broadcastLbtcLnSwap(
      swapId: swapId,
      signedTxHex: signedTxHex,
      broadcastViaBoltz: false,
    );
  }

  /// SEND BTC TO LN
  @override
  Future<LnSendSwap> createBitcoinToLightningSwap({
    required String mnemonic,
    required String walletId,
    required String invoice,
    required bool isTestnet,
    required String electrumUrl,
  }) async {
    final index = await _nextSubKeyIndex(walletId);
    final btcLnSwap = await _boltz.createBtcSubmarineSwap(
      walletId: walletId,
      mnemonic: mnemonic,
      index: index,
      invoice: invoice,
      isTestnet: isTestnet,
      electrumUrl: electrumUrl,
    );

    return btcLnSwap.toEntity() as LnSendSwap;
  }

  @override
  Future<void> coopSignBitcoinToLightningSwap({
    required String swapId,
  }) async {
    await _boltz.coopSignBtcSubmarineSwap(swapId: swapId);
    await _updateCompletedSendSwap(swapId: swapId);
    return;
  }

  @override
  Future<String> refundBitcoinToLightningSwap({
    required String swapId,
    required String bitcoinAddress,
    required int absoluteFees,
  }) async {
    final signedTxHex = await _boltz.refundBtcSubmarineSwap(
      swapId: swapId,
      refundAddress: bitcoinAddress,
      absoluteFees: absoluteFees,
      tryCooperate: true,
    );

    return await _boltz.broadcastBtcLnSwap(
      swapId: swapId,
      signedTxHex: signedTxHex,
      broadcastViaBoltz: false,
    );
  }

  /// SEND LBTC TO LN
  @override
  Future<LnSendSwap> createLiquidToLightningSwap({
    required String mnemonic,
    required String walletId,
    required String invoice,
    required bool isTestnet,
    required String electrumUrl,
  }) async {
    final index = await _nextSubKeyIndex(walletId);
    final lbtcLnSwap = await _boltz.createLbtcSubmarineSwap(
      walletId: walletId,
      mnemonic: mnemonic,
      index: index,
      invoice: invoice,
      isTestnet: isTestnet,
      electrumUrl: electrumUrl,
    );

    return lbtcLnSwap.toEntity() as LnSendSwap;
  }

  @override
  Future<void> coopSignLiquidToLightningSwap({
    required String swapId,
  }) async {
    await _boltz.coopSignLbtcSubmarineSwap(swapId: swapId);
    await _updateCompletedSendSwap(swapId: swapId);
    return;
  }

  @override
  Future<String> refundLiquidToLightningSwap({
    required String swapId,
    required String liquidAddress,
    required int absoluteFees,
  }) async {
    final signedTxHex = await _boltz.refundLbtcSubmarineSwap(
      swapId: swapId,
      refundAddress: liquidAddress,
      absoluteFees: absoluteFees,
      tryCooperate: true,
    );

    return await _boltz.broadcastLbtcLnSwap(
      swapId: swapId,
      signedTxHex: signedTxHex,
      broadcastViaBoltz: false,
    );
  }

  @override
  Future<Swap> createBitcoinToLiquidSwap({
    required String mnemonic,
    required String sendWalletId,
    required int amountSat,
    required bool isTestnet,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
    String? receiveWalletId,
    String? externalRecipientAddress,
  }) async {
    final index = await _nextChainKeyIndex(sendWalletId);
    final chainSwap = await _boltz.createBtcToLbtcChainSwap(
      sendWalletId: sendWalletId,
      mnemonic: mnemonic,
      index: index,
      amountSat: amountSat,
      isTestnet: isTestnet,
      btcElectrumUrl: btcElectrumUrl,
      lbtcElectrumUrl: lbtcElectrumUrl,
      receiveWalletId: receiveWalletId,
      externalRecipientAddress: externalRecipientAddress,
    );

    return chainSwap.toEntity();
  }

  @override
  Future<Swap> createLiquidToBitcoinSwap({
    required String mnemonic,
    required String sendWalletId,
    required int amountSat,
    required bool isTestnet,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
    String? receiveWalletId,
    String? externalRecipientAddress,
  }) async {
    final index = await _nextChainKeyIndex(sendWalletId);
    final chainSwap = await _boltz.createLbtcToBtcChainSwap(
      sendWalletId: sendWalletId,
      mnemonic: mnemonic,
      index: index,
      amountSat: amountSat,
      isTestnet: isTestnet,
      btcElectrumUrl: btcElectrumUrl,
      lbtcElectrumUrl: lbtcElectrumUrl,
      receiveWalletId: receiveWalletId,
      externalRecipientAddress: externalRecipientAddress,
    );

    return chainSwap.toEntity();
  }

  @override
  Future<String> claimLiquidToBitcoinSwap({
    required String swapId,
    required String bitcoinClaimAddress,
    required String liquidRefundAddress,
    required int absoluteFees,
  }) async {
    final signedTxHex = await _boltz.claimLbtcToBtcChainSwap(
      swapId: swapId,
      claimBitcoinAddress: bitcoinClaimAddress,
      refundLiquidAddress: liquidRefundAddress,
      absoluteFees: absoluteFees,
      tryCooperate: true,
    );

    return await _boltz.broadcastChainSwapClaim(
      swapId: swapId,
      signedTxHex: signedTxHex,
      broadcastViaBoltz: false,
    );
  }

  @override
  Future<String> claimBitcoinToLiquidSwap({
    required String swapId,
    required String liquidClaimAddress,
    required String bitcoinRefundAddress,
    required int absoluteFees,
  }) async {
    final signedTxHex = await _boltz.claimBtcToLbtcChainSwap(
      swapId: swapId,
      claimLiquidAddress: liquidClaimAddress,
      refundBitcoinAddress: bitcoinRefundAddress,
      absoluteFees: absoluteFees,
      tryCooperate: true,
    );

    return await _boltz.broadcastChainSwapClaim(
      swapId: swapId,
      signedTxHex: signedTxHex,
      broadcastViaBoltz: false,
    );
  }

  @override
  Future<String> refundBitcoinToLiquidSwap({
    required String swapId,
    required String bitcoinRefundAddress,
    required int absoluteFees,
  }) async {
    final signedTxHex = await _boltz.refundBtcToLbtcChainSwap(
      swapId: swapId,
      refundBitcoinAddress: bitcoinRefundAddress,
      absoluteFees: absoluteFees,
      tryCooperate: true,
    );

    return await _boltz.broadcastChainSwapRefund(
      swapId: swapId,
      signedTxHex: signedTxHex,
      broadcastViaBoltz: false,
    );
  }

  @override
  Future<String> refundLiquidToBitcoinSwap({
    required String swapId,
    required String liquidRefundAddress,
    required int absoluteFees,
  }) async {
    final signedTxHex = await _boltz.refundLbtcToBtcChainSwap(
      swapId: swapId,
      refundLiquidAddress: liquidRefundAddress,
      absoluteFees: absoluteFees,
      tryCooperate: true,
    );

    return await _boltz.broadcastChainSwapRefund(
      swapId: swapId,
      signedTxHex: signedTxHex,
      broadcastViaBoltz: false,
    );
  }

  // STORAGE
  @override
  Future<Swap> getSwap({required String swapId}) async {
    final swapModel = await _boltz.storage.get(swapId);
    if (swapModel == null) {
      throw "No swap found";
    }
    return swapModel.toEntity();
  }

  @override
  Future<void> updatePaidSendSwap({
    required String swapId,
    required String txid,
  }) async {
    final swapModel = await _boltz.storage.get(swapId);
    if (swapModel == null) {
      throw "No swap model found";
    }

    final swap = swapModel.toEntity();
    if (swap.status != SwapStatus.pending) {
      throw "Can only update status of a pending swap";
    }

    // Use the appropriate variant's copyWith method
    final updatedSwap = swap.maybeMap(
      lnSend: (lnSendSwap) => lnSendSwap.copyWith(
        sendTxid: txid,
        status: SwapStatus.paid,
      ),
      chain: (chainSwap) => chainSwap.copyWith(
        sendTxid: txid,
        status: SwapStatus.paid,
      ),
      orElse: () => throw "Only lnSend or chain swaps can be marked as paid",
    );

    await _boltz.storage.store(SwapModel.fromEntity(updatedSwap));
  }

  Future<void> updateExpiredSwap({
    required String swapId,
  }) async {
    final swapModel = await _boltz.storage.get(swapId);
    if (swapModel == null) {
      throw "No swap model found";
    }
    final swap = swapModel.toEntity();
    if (swap.status != SwapStatus.pending) {
      throw "Can only update status of a pending swap";
    }
    final updatedSwap = swap.copyWith(
      status: SwapStatus.expired,
    );
    await _boltz.storage.store(SwapModel.fromEntity(updatedSwap));
  }

  Future<void> updateFailedSwap({
    required String swapId,
  }) async {
    final swapModel = await _boltz.storage.get(swapId);
    if (swapModel == null) {
      throw "No swap model found";
    }
    final swap = swapModel.toEntity();
    if (swap.status != SwapStatus.pending) {
      throw "Can only update status of a pending swap";
    }
    final updatedSwap = swap.copyWith(
      status: SwapStatus.failed,
    );
    await _boltz.storage.store(SwapModel.fromEntity(updatedSwap));
  }

  /// PRIVATE
  Future<void> _updateCompletedSendSwap({
    required String swapId,
  }) async {
    final swapModel = await _boltz.storage.get(swapId);
    if (swapModel == null) {
      throw "No swap model found";
    }

    final swap = swapModel.toEntity();
    if (swap.status != SwapStatus.paid) {
      throw "Can only update status of a paid swap";
    }

    // Handle each type separately
    final updatedSwap = swap.map(
      lnReceive: (lnReceiveSwap) => lnReceiveSwap.copyWith(
        completionTime: DateTime.now(),
        status: SwapStatus.completed,
      ),
      lnSend: (lnSendSwap) => lnSendSwap.copyWith(
        completionTime: DateTime.now(),
        status: SwapStatus.completed,
      ),
      chain: (chainSwap) => chainSwap.copyWith(
        completionTime: DateTime.now(),
        status: SwapStatus.completed,
      ),
    );

    await _boltz.storage.store(SwapModel.fromEntity(updatedSwap));
  }

  Future<int> _nextRevKeyIndex(String walletId) async {
    final swaps = await _getRevSwapsForWallet(walletId);
    final nextWalletIndex =
        swaps.isEmpty ? 0 : swaps.map((swap) => swap.keyIndex).reduce(max) + 1;
    return nextWalletIndex;
  }

  Future<List<Swap>> _getRevSwapsForWallet(String walletId) async {
    return (await _boltz.storage.getAll())
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
    final nextWalletIndex =
        swaps.isEmpty ? 0 : swaps.map((swap) => swap.keyIndex).reduce(max) + 1;
    return nextWalletIndex;
  }

  Future<List<Swap>> _getSubSwapsForWallet(String walletId) async {
    return (await _boltz.storage.getAll())
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
    final nextWalletIndex =
        swaps.isEmpty ? 0 : swaps.map((swap) => swap.keyIndex).reduce(max) + 1;
    return nextWalletIndex;
  }

  Future<List<Swap>> _getChainSwapsForWallet(String walletId) async {
    return (await _boltz.storage.getAll())
        .map((swapModel) => swapModel.toEntity())
        .where(
          (swap) =>
              swap.type == SwapType.bitcoinToLiquid ||
              swap.type == SwapType.liquidToBitcoin,
        )
        .toList();
  }

  @override
  Future<void> updateSwap({required Swap swap}) {
    return _boltz.storage.store(SwapModel.fromEntity(swap));
  }

  @override
  Future<void> reinitializeStreamWithSwaps({required List<String> swapIds}) {
    _boltz.resetStream();
    _boltz.subscribeToSwaps(swapIds);
    final allSwapsToWatch = swapIds.map((swapId) async {
      final swap = await _boltz.storage.get(swapId);
      return swap?.toEntity();
    });
    // add to the swapUpdateStream
    return Future.wait(allSwapsToWatch).then((swaps) {
      for (final swap in swaps) {
        if (swap != null) {
          _boltz.swapUpdatesController.add(SwapModel.fromEntity(swap));
        }
      }
    });
  }

  @override
  Future<List<Swap>> getOngoingSwaps() async {
    final allSwapModels = await _boltz.storage.getAll();
    final allSwaps =
        allSwapModels.map((swapModel) => swapModel.toEntity()).toList();
    return allSwaps
        .where(
          (swap) =>
              swap.status == SwapStatus.pending ||
              swap.status == SwapStatus.paid ||
              swap.status == SwapStatus.claimable ||
              swap.status == SwapStatus.refundable ||
              swap.status == SwapStatus.canCoop,
        )
        .toList();
  }

  @override
  Future<List<Swap>> getAllSwaps() async {
    final allSwapModels = await _boltz.storage.getAll();
    final allSwaps =
        allSwapModels.map((swapModel) => swapModel.toEntity()).toList();
    return allSwaps;
  }

  @override
  Future<SwapLimits> getSwapLimits({
    required SwapType type,
  }) async {
    switch (type) {
      case SwapType.lightningToBitcoin:
        final (min, max) = await _boltz.getBtcReverseSwapLimits();
        return SwapLimits(min: min, max: max);
      case SwapType.lightningToLiquid:
        final (min, max) = await _boltz.getLbtcReverseSwapLimits();
        return SwapLimits(min: min, max: max);
      case SwapType.liquidToLightning:
        final (min, max) = await _boltz.getLbtcSubmarineSwapLimits();
        return SwapLimits(min: min, max: max);
      case SwapType.bitcoinToLightning:
        final (min, max) = await _boltz.getBtcSubmarineSwapLimits();
        return SwapLimits(min: min, max: max);
      case SwapType.liquidToBitcoin:
        final (min, max) = await _boltz.getLbtcToBtcChainSwapLimits();
        return SwapLimits(min: min, max: max);
      case SwapType.bitcoinToLiquid:
        final (min, max) = await _boltz.getBtcToLbtcChainSwapLimits();
        return SwapLimits(min: min, max: max);
    }
  }

  @override
  Future<Invoice> decodeInvoice({required String invoice}) async {
    // TODO: implement decodeInvoice
    final (sats, expired, bip21) = await _boltz.decodeInvoice(invoice);
    return Invoice(
      sats: sats,
      isExpired: expired,
      magicBip21: bip21,
    );
  }
}
