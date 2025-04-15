import 'dart:async';

import 'package:bb_mobile/core/swaps/data/datasources/boltz_storage_datasource.dart';
import 'package:bb_mobile/core/swaps/data/models/swap_model.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart' as swap_entity;
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:boltz/boltz.dart';
import 'package:flutter/material.dart';

class BoltzDatasource {
  final String _baseUrl;
  late String _httpsUrl;

  late BoltzWebSocket _boltzWebSocket;
  final BoltzStorageDatasource _boltzStore;

  StreamController<SwapModel> _swapUpdatesController =
      StreamController<SwapModel>.broadcast();

  BoltzDatasource({
    String url = ApiServiceConstants.boltzMainnetUrlPath,
    required BoltzStorageDatasource boltzStore,
  })  : _baseUrl = url,
        _boltzStore = boltzStore {
    _httpsUrl = 'https://$_baseUrl';
    _initializeBoltzWebSocket();
  }

  BoltzStorageDatasource get storage => _boltzStore;

  Stream<SwapModel> get swapUpdatesStream => _swapUpdatesController.stream;

  StreamController<SwapModel> get swapUpdatesController =>
      _swapUpdatesController;

  // REVERSE SWAPS
  Future<SwapModel> createBtcReverseSwap({
    required String origin,
    required String mnemonic,
    required int index,
    required int outAmount,
    required bool isTestnet,
    required String electrumUrl,
    required String magicRouteHintAddress,
    String? description,
  }) async {
    final fees = Fees(boltzUrl: _httpsUrl);
    final reverseFees = await fees.reverse();
    final btcLnSwap = await BtcLnSwap.newReverse(
      mnemonic: mnemonic,
      index: BigInt.from(index),
      outAmount: BigInt.from(outAmount),
      network: isTestnet ? Chain.bitcoinTestnet : Chain.bitcoin,
      electrumUrl: electrumUrl,
      boltzUrl: _httpsUrl,
      outAddress: magicRouteHintAddress,
      description: description,
    );
    await _boltzStore.storeBtcLnSwap(btcLnSwap);
    final swapModel = SwapModel.lnReceive(
      id: btcLnSwap.id,
      status: swap_entity.SwapStatus.pending.name,
      type: swap_entity.SwapType.lightningToBitcoin.name,
      isTestnet: isTestnet,
      keyIndex: index,
      creationTime: DateTime.now().millisecondsSinceEpoch,
      receiveWalletId: origin,
      invoice: btcLnSwap.invoice,
      boltzFees: (reverseFees.btcFees.percentage * outAmount / 100).ceil(),
      lockupFees: reverseFees.btcFees.minerFees.lockup.toInt(),
      claimFees: reverseFees.btcFees.minerFees.claim.toInt(),
      receiveAddress: magicRouteHintAddress,
    );
    await _boltzStore.store(swapModel);
    subscribeToSwaps([swapModel.id]);
    return swapModel;
  }

  Future<String> claimBtcReverseSwap({
    required String swapId,
    required String claimAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    final btcLnSwap = await _boltzStore.getBtcLnSwap(swapId);

    return btcLnSwap.claim(
      outAddress: claimAddress,
      minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
      tryCooperate: tryCooperate,
    );
  }

  Future<SwapModel> createLBtcReverseSwap({
    required String origin,
    required String mnemonic,
    required int index,
    required int outAmount,
    required bool isTestnet,
    required String electrumUrl,
    required String magicRouteHintAddress,
    String? description,
  }) async {
    try {
      final fees = Fees(boltzUrl: _httpsUrl);
      final reverseFees = await fees.reverse();
      final lbtcLnSwap = await LbtcLnSwap.newReverse(
        mnemonic: mnemonic,
        index: BigInt.from(index),
        outAmount: BigInt.from(outAmount),
        network: isTestnet ? Chain.liquidTestnet : Chain.liquid,
        electrumUrl: electrumUrl,
        boltzUrl: _httpsUrl,
        outAddress: magicRouteHintAddress,
        description: description,
      );

      await _boltzStore.storeLbtcLnSwap(lbtcLnSwap);

      final swapModel = SwapModel.lnReceive(
        id: lbtcLnSwap.id,
        status: swap_entity.SwapStatus.pending.name,
        type: swap_entity.SwapType.lightningToLiquid.name,
        isTestnet: isTestnet,
        keyIndex: index,
        creationTime: DateTime.now().millisecondsSinceEpoch,
        receiveWalletId: origin,
        invoice: lbtcLnSwap.invoice,
        boltzFees: (reverseFees.lbtcFees.percentage * outAmount / 100).ceil(),
        lockupFees: reverseFees.lbtcFees.minerFees.lockup.toInt(),
        claimFees: reverseFees.lbtcFees.minerFees.claim.toInt(),
        receiveAddress: magicRouteHintAddress,
      );

      await _boltzStore.store(swapModel);
      subscribeToSwaps([swapModel.id]);

      return swapModel;
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
  }

  Future<String> claimLBtcReverseSwap({
    required String swapId,
    required String claimAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    final lbtcLnSwap = await _boltzStore.getLbtcLnSwap(swapId);

    return lbtcLnSwap.claim(
      outAddress: claimAddress,
      minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
      tryCooperate: tryCooperate,
    );
  }

  Future<String> broadcastBtcLnSwap({
    required String swapId,
    required String signedTxHex,
    required bool broadcastViaBoltz,
  }) async {
    final btcLnSwap = await _boltzStore.getBtcLnSwap(swapId);

    return broadcastViaBoltz
        ? btcLnSwap.broadcastLocal(
            signedHex: signedTxHex,
          )
        : btcLnSwap.broadcastBoltz(
            signedHex: signedTxHex,
          );
  }

  Future<String> broadcastLbtcLnSwap({
    required String swapId,
    required String signedTxHex,
    required bool broadcastViaBoltz,
  }) async {
    final lbtcLnSwap = await _boltzStore.getLbtcLnSwap(swapId);

    return broadcastViaBoltz
        ? lbtcLnSwap.broadcastLocal(
            signedHex: signedTxHex,
          )
        : lbtcLnSwap.broadcastBoltz(
            signedHex: signedTxHex,
          );
  }

  Future<SwapModel> createBtcSubmarineSwap({
    required String origin,
    required String mnemonic,
    required int index,
    required String invoice,
    required bool isTestnet,
    required String electrumUrl,
  }) async {
    final fees = Fees(boltzUrl: _httpsUrl);
    final submarineFees = await fees.submarine();
    final btcLnSwap = await BtcLnSwap.newSubmarine(
      mnemonic: mnemonic,
      index: BigInt.from(index),
      invoice: invoice,
      network: isTestnet ? Chain.bitcoinTestnet : Chain.bitcoin,
      electrumUrl: electrumUrl,
      boltzUrl: _httpsUrl,
    );

    await _boltzStore.storeBtcLnSwap(btcLnSwap);

    final swapModel = SwapModel.lnSend(
      id: btcLnSwap.id,
      status: swap_entity.SwapStatus.pending.name,
      type: swap_entity.SwapType.bitcoinToLightning.name,
      isTestnet: isTestnet,
      keyIndex: index,
      creationTime: DateTime.now().millisecondsSinceEpoch,
      sendWalletId: origin,
      invoice: invoice,
      paymentAddress: btcLnSwap.scriptAddress,
      paymentAmount: btcLnSwap.outAmount.toInt(),
      boltzFees: (submarineFees.btcFees.percentage *
              (btcLnSwap.outAmount.toInt()) /
              100)
          .ceil(),
      lockupFees: submarineFees.btcFees.minerFees.toInt(),
      claimFees: submarineFees.btcFees.minerFees.toInt(),
    );
    await _boltzStore.store(swapModel);
    subscribeToSwaps([swapModel.id]);

    return swapModel;
  }

  Future<SwapModel> createLbtcSubmarineSwap({
    required String origin,
    required String mnemonic,
    required int index,
    required String invoice,
    required bool isTestnet,
    required String electrumUrl,
  }) async {
    final fees = Fees(boltzUrl: _httpsUrl);
    final submarineFees = await fees.submarine();
    final lbtcLnSwap = await LbtcLnSwap.newSubmarine(
      mnemonic: mnemonic,
      index: BigInt.from(index),
      invoice: invoice,
      network: isTestnet ? Chain.liquidTestnet : Chain.liquid,
      electrumUrl: electrumUrl,
      boltzUrl: _httpsUrl,
    );

    await _boltzStore.storeLbtcLnSwap(lbtcLnSwap);

    final swapModel = SwapModel.lnSend(
      id: lbtcLnSwap.id,
      status: swap_entity.SwapStatus.pending.name,
      type: swap_entity.SwapType.liquidToLightning.name,
      isTestnet: isTestnet,
      keyIndex: index,
      creationTime: DateTime.now().millisecondsSinceEpoch,
      sendWalletId: origin,
      invoice: invoice,
      paymentAddress: lbtcLnSwap.scriptAddress,
      paymentAmount: lbtcLnSwap.outAmount.toInt(),
      boltzFees: (submarineFees.lbtcFees.percentage *
              (lbtcLnSwap.outAmount.toInt()) /
              100)
          .ceil(),
      lockupFees: submarineFees.lbtcFees.minerFees.toInt(),
      claimFees: submarineFees.lbtcFees.minerFees.toInt(),
    );

    await _boltzStore.store(swapModel);
    subscribeToSwaps([swapModel.id]);

    return swapModel;
  }

  Future<void> coopSignBtcSubmarineSwap({required String swapId}) async {
    final btcLnSwap = await _boltzStore.getBtcLnSwap(swapId);
    return btcLnSwap.coopCloseSubmarine();
  }

  Future<void> coopSignLbtcSubmarineSwap({required String swapId}) async {
    final lbtcLnSwap = await _boltzStore.getLbtcLnSwap(swapId);
    await lbtcLnSwap.coopCloseSubmarine();
    return;
  }

  Future<String> refundBtcSubmarineSwap({
    required String swapId,
    required String refundAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    final btcLnSwap = await _boltzStore.getBtcLnSwap(swapId);
    return btcLnSwap.refund(
      outAddress: refundAddress,
      minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
      tryCooperate: tryCooperate,
    );
  }

  Future<String> refundLbtcSubmarineSwap({
    required String swapId,
    required String refundAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    final lbtcLnSwap = await _boltzStore.getLbtcLnSwap(swapId);
    debugPrint(lbtcLnSwap.id);
    debugPrint(lbtcLnSwap.network.toString());
    return lbtcLnSwap.refund(
      outAddress: refundAddress,
      minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
      tryCooperate: tryCooperate,
    );
  }

  Future<SwapModel> createBtcToLbtcChainSwap({
    required String sendWalletId,
    required String mnemonic,
    required int index,
    required int amountSat,
    required bool isTestnet,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
    String? receiveWalletId,
    String? externalRecipientAddress,
  }) async {
    final fees = Fees(boltzUrl: _httpsUrl);
    final chainFees = await fees.chain();
    final chainSwap = await ChainSwap.newSwap(
      mnemonic: mnemonic,
      index: BigInt.from(index),
      boltzUrl: _httpsUrl,
      direction: ChainSwapDirection.btcToLbtc,
      amount: BigInt.from(amountSat),
      isTestnet: isTestnet,
      btcElectrumUrl: btcElectrumUrl,
      lbtcElectrumUrl: lbtcElectrumUrl,
    );

    await _boltzStore.storeChainSwap(chainSwap);

    final swapModel = SwapModel.chain(
      id: chainSwap.id,
      status: swap_entity.SwapStatus.pending.name,
      type: swap_entity.SwapType.bitcoinToLiquid.name,
      isTestnet: isTestnet,
      keyIndex: index,
      creationTime: DateTime.now().millisecondsSinceEpoch,
      sendWalletId: sendWalletId,
      receiveWalletId: receiveWalletId,
      receiveAddress: externalRecipientAddress,
      boltzFees: (chainFees.lbtcFees.percentage * amountSat / 100).ceil(),
      lockupFees: chainFees.btcFees.userLockup.toInt() +
          chainFees.btcFees.server.toInt() +
          chainFees.lbtcFees.server.toInt(),
      claimFees: chainFees.lbtcFees.userClaim.toInt(),
    );
    await _boltzStore.store(swapModel);
    subscribeToSwaps([swapModel.id]);
    return swapModel;
  }

  Future<SwapModel> createLbtcToBtcChainSwap({
    required String sendWalletId,
    required String mnemonic,
    required int index,
    required int amountSat,
    required bool isTestnet,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
    String? receiveWalletId,
    String? externalRecipientAddress,
  }) async {
    final fees = Fees(boltzUrl: _httpsUrl);
    final chainFees = await fees.chain();

    final chainSwap = await ChainSwap.newSwap(
      mnemonic: mnemonic,
      index: BigInt.from(index),
      boltzUrl: _httpsUrl,
      direction: ChainSwapDirection.lbtcToBtc,
      amount: BigInt.from(amountSat),
      isTestnet: isTestnet,
      btcElectrumUrl: btcElectrumUrl,
      lbtcElectrumUrl: lbtcElectrumUrl,
    );

    await _boltzStore.storeChainSwap(chainSwap);

    final swapModel = SwapModel.chain(
      id: chainSwap.id,
      status: swap_entity.SwapStatus.pending.name,
      type: swap_entity.SwapType.liquidToBitcoin.name,
      isTestnet: isTestnet,
      keyIndex: index,
      creationTime: DateTime.now().millisecondsSinceEpoch,
      sendWalletId: sendWalletId,
      receiveWalletId: receiveWalletId,
      receiveAddress: externalRecipientAddress,
      boltzFees: (chainFees.btcFees.percentage * amountSat / 100).ceil(),
      lockupFees: chainFees.lbtcFees.userLockup.toInt() +
          chainFees.btcFees.server.toInt() +
          chainFees.lbtcFees.server.toInt(),
      claimFees: chainFees.btcFees.userClaim.toInt(),
    );
    await _boltzStore.store(swapModel);
    subscribeToSwaps([swapModel.id]);

    return swapModel;
  }

  Future<String> broadcastChainSwapRefund({
    required String swapId,
    required String signedTxHex,
    required bool broadcastViaBoltz,
  }) async {
    final chainSwap = await _boltzStore.getChainSwap(swapId);
    return broadcastViaBoltz
        ? chainSwap.broadcastLocal(
            signedHex: signedTxHex,
            kind: SwapTxKind.refund,
          )
        : chainSwap.broadcastBoltz(
            signedHex: signedTxHex,
            kind: SwapTxKind.refund,
          );
  }

  Future<String> claimBtcToLbtcChainSwap({
    required String swapId,
    required String claimLiquidAddress,
    required String refundBitcoinAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    final chainSwap = await _boltzStore.getChainSwap(swapId);
    return await chainSwap.claim(
      outAddress: claimLiquidAddress,
      refundAddress: refundBitcoinAddress,
      minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
      tryCooperate: tryCooperate,
    );
  }

  Future<String> claimLbtcToBtcChainSwap({
    required String swapId,
    required String claimBitcoinAddress,
    required String refundLiquidAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    final chainSwap = await _boltzStore.getChainSwap(swapId);
    return await chainSwap.claim(
      outAddress: claimBitcoinAddress,
      refundAddress: refundLiquidAddress,
      minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
      tryCooperate: tryCooperate,
    );
  }

  Future<String> broadcastChainSwapClaim({
    required String swapId,
    required String signedTxHex,
    required bool broadcastViaBoltz,
  }) async {
    final chainSwap = await _boltzStore.getChainSwap(swapId);
    return broadcastViaBoltz
        ? chainSwap.broadcastLocal(
            signedHex: signedTxHex,
            kind: SwapTxKind.claim,
          )
        : chainSwap.broadcastBoltz(
            signedHex: signedTxHex,
            kind: SwapTxKind.claim,
          );
  }

  Future<String> refundBtcToLbtcChainSwap({
    required String swapId,
    required String refundBitcoinAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    final chainSwap = await _boltzStore.getChainSwap(swapId);
    return await chainSwap.refund(
      refundAddress: refundBitcoinAddress,
      minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
      tryCooperate: tryCooperate,
    );
  }

  Future<String> refundLbtcToBtcChainSwap({
    required String swapId,
    required String refundLiquidAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    final chainSwap = await _boltzStore.getChainSwap(swapId);
    return await chainSwap.refund(
      refundAddress: refundLiquidAddress,
      minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
      tryCooperate: tryCooperate,
    );
  }

  Future<(int, int)> getBtcReverseSwapLimits() async {
    try {
      final fees = Fees(boltzUrl: _httpsUrl);
      final reverse = await fees.reverse();
      return (
        reverse.btcLimits.minimal.toInt(),
        reverse.btcLimits.maximal.toInt()
      );
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
  }

  Future<(int, int)> getLbtcReverseSwapLimits() async {
    try {
      final fees = Fees(boltzUrl: _httpsUrl);
      final reverse = await fees.reverse();
      return (
        reverse.lbtcLimits.minimal.toInt(),
        reverse.lbtcLimits.maximal.toInt()
      );
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
  }

  Future<(int, int)> getBtcSubmarineSwapLimits() async {
    final fees = Fees(boltzUrl: _httpsUrl);
    final submarine = await fees.submarine();
    return (
      submarine.btcLimits.minimal.toInt(),
      submarine.btcLimits.maximal.toInt()
    );
  }

  Future<(int, int)> getLbtcSubmarineSwapLimits() async {
    final fees = Fees(boltzUrl: _httpsUrl);
    final submarine = await fees.submarine();
    return (
      submarine.lbtcLimits.minimal.toInt(),
      submarine.lbtcLimits.maximal.toInt()
    );
  }

  Future<(int, int)> getBtcToLbtcChainSwapLimits() async {
    final fees = Fees(boltzUrl: _httpsUrl);
    final chain = await fees.chain();
    return (chain.btcLimits.minimal.toInt(), chain.btcLimits.maximal.toInt());
  }

  Future<(int, int)> getLbtcToBtcChainSwapLimits() async {
    final fees = Fees(boltzUrl: _httpsUrl);
    final chain = await fees.chain();
    return (chain.lbtcLimits.minimal.toInt(), chain.lbtcLimits.maximal.toInt());
  }

  void _initializeBoltzWebSocket() {
    try {
      _boltzWebSocket = BoltzWebSocket.create(_baseUrl);
      if (_swapUpdatesController.isClosed) {
        _swapUpdatesController = StreamController<SwapModel>.broadcast();
      }
      _boltzWebSocket.stream.listen(
        (event) async {
          final swapId = event.id;
          final boltzStatus = event.status;
          try {
            final swapModel = await _boltzStore.get(swapId);
            if (swapModel == null) {
              debugPrint('No swap found for id: $swapId');
              return;
            }
            // Check if swap is already in terminal state
            final swapCompleted =
                swapModel.status == swap_entity.SwapStatus.completed.name;
            final swapFailed =
                swapModel.status == swap_entity.SwapStatus.failed.name;
            final swapExpired =
                swapModel.status == swap_entity.SwapStatus.expired.name;

            if (swapCompleted || swapFailed || swapExpired) {
              // Unsubscribe from the swap if it's in a terminal state
              unsubscribeToSwaps([swapId]);
            }
            // Process the event
            SwapModel? updatedSwapModel;
            switch (boltzStatus) {
              case SwapStatus.swapCreated:
              case SwapStatus.invoiceSet:
              case SwapStatus.invoicePending:
              case SwapStatus.minerfeePaid:
                // No action needed for these status updates
                return;

              case SwapStatus.invoicePaid:
              case SwapStatus.txnClaimPending:
                // Handle cooperative closing for submarine swaps
                if (swapModel is LnSendSwapModel) {
                  updatedSwapModel = swapModel.copyWith(
                    status: swap_entity.SwapStatus.canCoop.name,
                  );
                }

              case SwapStatus.invoiceSettled:
                // Invoice settled for reverse swaps
                if (swapModel is LnReceiveSwapModel) {
                  updatedSwapModel = swapModel.copyWith(
                    status: swap_entity.SwapStatus.completed.name,
                  );
                }

              case SwapStatus.invoiceFailedToPay:
                // Failed submarine swap
                final submarineLockupPaid =
                    swapModel is LnSendSwapModel && swapModel.sendTxid != null;
                final hasRefunded =
                    (swapModel as LnSendSwapModel).refundTxid != null;
                if (submarineLockupPaid && !hasRefunded) {
                  updatedSwapModel = swapModel.copyWith(
                    status: swap_entity.SwapStatus.refundable.name,
                  );
                }

              case SwapStatus.txnMempool:
                // For reverse swaps on Liquid, no confirmation needed
                if (swapModel is LnReceiveSwapModel) {
                  final type = swapModel.type;
                  if (type == swap_entity.SwapType.lightningToLiquid.name) {
                    updatedSwapModel = swapModel.copyWith(
                      status: swap_entity.SwapStatus.claimable.name,
                    );
                  }
                  if (type == swap_entity.SwapType.lightningToBitcoin.name) {
                    updatedSwapModel = swapModel.copyWith(
                      status: swap_entity.SwapStatus.paid.name,
                    );
                  }
                }

              case SwapStatus.txnConfirmed:
                // For reverse swaps on Bitcoin or chain swaps
                if (swapModel is LnReceiveSwapModel) {
                  updatedSwapModel = swapModel.copyWith(
                    status: swap_entity.SwapStatus.claimable.name,
                  );
                }

              case SwapStatus.txnClaimed:
                // Swap has been claimed successfully
                updatedSwapModel = swapModel.copyWith(
                  status: swap_entity.SwapStatus.completed.name,
                  completionTime: DateTime.now().millisecondsSinceEpoch,
                );

              case SwapStatus.txnRefunded:
                // Check if this swap needs to be refunded (no refundTxid)
                if (swapModel is ChainSwapModel ||
                    swapModel is LnSendSwapModel) {
                  final refunded = swapModel is ChainSwapModel
                      ? swapModel.refundTxid != null
                      : (swapModel as LnSendSwapModel).refundTxid != null;

                  if (!refunded) {
                    updatedSwapModel = swapModel.copyWith(
                      status: swap_entity.SwapStatus.refundable.name,
                    );
                  } else {
                    // Already refunded, mark as completed
                    updatedSwapModel = swapModel.copyWith(
                      status: swap_entity.SwapStatus.completed.name,
                      completionTime: DateTime.now().millisecondsSinceEpoch,
                    );
                  }
                } else if (swapModel is LnReceiveSwapModel) {
                  // For reverse swaps, this means failure
                  updatedSwapModel = swapModel.copyWith(
                    status: swap_entity.SwapStatus.failed.name,
                  );
                }

              case SwapStatus.txnLockupFailed:
              case SwapStatus.txnFailed:
                // Transaction failed - check if refundable
                if (swapModel is ChainSwapModel ||
                    swapModel is LnSendSwapModel) {
                  final hasSentFunds = swapModel is ChainSwapModel
                      ? swapModel.sendTxid != null
                      : (swapModel as LnSendSwapModel).sendTxid != null;

                  final hasRefunded = swapModel is ChainSwapModel
                      ? swapModel.refundTxid != null
                      : (swapModel as LnSendSwapModel).refundTxid != null;

                  if (hasSentFunds && !hasRefunded) {
                    updatedSwapModel = swapModel.copyWith(
                      status: swap_entity.SwapStatus.refundable.name,
                    );
                  } else {
                    updatedSwapModel = swapModel.copyWith(
                      status: swap_entity.SwapStatus.failed.name,
                    );
                  }
                }

              case SwapStatus.swapExpired:
              case SwapStatus.invoiceExpired:
                // Check if funds were sent but not refunded
                if (swapModel is ChainSwapModel ||
                    swapModel is LnSendSwapModel) {
                  final hasSentFunds = swapModel is ChainSwapModel
                      ? swapModel.sendTxid != null
                      : (swapModel as LnSendSwapModel).sendTxid != null;

                  final hasRefunded = swapModel is ChainSwapModel
                      ? swapModel.refundTxid != null
                      : (swapModel as LnSendSwapModel).refundTxid != null;

                  if (hasSentFunds && !hasRefunded) {
                    updatedSwapModel = swapModel.copyWith(
                      status: swap_entity.SwapStatus.refundable.name,
                    );
                  } else {
                    updatedSwapModel = swapModel.copyWith(
                      status: swap_entity.SwapStatus.expired.name,
                    );
                  }
                } else if (swapModel is LnReceiveSwapModel) {
                  updatedSwapModel = swapModel.copyWith(
                    status: swap_entity.SwapStatus.expired.name,
                  );
                }

              case SwapStatus.swapRefunded:
                if (swapModel is ChainSwapModel ||
                    swapModel is LnSendSwapModel) {
                  final hasRefunded = swapModel is ChainSwapModel
                      ? swapModel.refundTxid != null
                      : (swapModel as LnSendSwapModel).refundTxid != null;

                  if (!hasRefunded) {
                    updatedSwapModel = swapModel.copyWith(
                      status: swap_entity.SwapStatus.refundable.name,
                    );
                  } else {
                    updatedSwapModel = swapModel.copyWith(
                      status: swap_entity.SwapStatus.completed.name,
                      completionTime: DateTime.now().millisecondsSinceEpoch,
                    );
                  }
                }

              case SwapStatus.swapError:
                // Handle error states
                if (swapModel is ChainSwapModel ||
                    swapModel is LnSendSwapModel) {
                  final hasSentFunds = swapModel is ChainSwapModel
                      ? swapModel.sendTxid != null
                      : (swapModel as LnSendSwapModel).sendTxid != null;

                  final hasRefunded = swapModel is ChainSwapModel
                      ? swapModel.refundTxid != null
                      : (swapModel as LnSendSwapModel).refundTxid != null;

                  if (hasSentFunds && !hasRefunded) {
                    updatedSwapModel = swapModel.copyWith(
                      status: swap_entity.SwapStatus.refundable.name,
                    );
                  } else {
                    updatedSwapModel = swapModel.copyWith(
                      status: swap_entity.SwapStatus.failed.name,
                    );
                  }
                } else {
                  updatedSwapModel = swapModel.copyWith(
                    status: swap_entity.SwapStatus.failed.name,
                  );
                }

              case SwapStatus.txnServerMempool:
              case SwapStatus.txnServerConfirmed:
                // Handle server-side transaction states
                if (swapModel is ChainSwapModel) {
                  final type = swapModel.type;
                  // For liquid swaps, mempool is enough, BTC needs confirmation
                  final isLiquid =
                      type == swap_entity.SwapType.bitcoinToLiquid.name;
                  final isMempoolEnough =
                      isLiquid && boltzStatus == SwapStatus.txnServerMempool;
                  final isConfirmed =
                      boltzStatus == SwapStatus.txnServerConfirmed;

                  if (isMempoolEnough || isConfirmed) {
                    updatedSwapModel = swapModel.copyWith(
                      status: swap_entity.SwapStatus.claimable.name,
                    );
                  }
                }
            }

            // Update storage and emit event if status changed
            if (updatedSwapModel != null) {
              await _boltzStore.store(updatedSwapModel);
              debugPrint(
                'Updated swap $swapId from ${swapModel.status} to ${updatedSwapModel.status}',
              );
              _swapUpdatesController.add(updatedSwapModel);
            }
          } catch (e) {
            debugPrint('Error processing swap status update: $e');
          }
        },
        onError: (error) {
          debugPrint('Boltz WebSocket error: $error');
          _swapUpdatesController.addError(error.toString());
        },
        onDone: () {},
      );

      debugPrint('Started Boltz WebSocket');
    } catch (e) {
      debugPrint('Error initializing BoltzWebSocket: $e');
      // Don't rethrow here to allow for graceful recovery
    }
  }

  Future<void> reconnect() async {
    try {
      debugPrint('Attempting to reconnect to Boltz WebSocket...');
      resetStream();
    } catch (e) {
      debugPrint('Failed to reconnect: $e');
    }
  }

  void resetStream() {
    try {
      _boltzWebSocket.dispose();
      debugPrint('Boltz WebSocket connection closed');
    } catch (e) {
      debugPrint('Error disposing WebSocket: $e');
    }
    _swapUpdatesController.close();
    _initializeBoltzWebSocket();
  }

  void subscribeToSwaps(List<String> swapIds) {
    try {
      _boltzWebSocket.subscribe(swapIds);
    } catch (e) {
      debugPrint('Error subscribing to swaps: $e');
    }
  }

  void unsubscribeToSwaps(List<String> swapIds) {
    try {
      _boltzWebSocket.unsubscribe(swapIds);
    } catch (e) {
      debugPrint('Error unsubscribing from swaps: $e');
    }
  }

  Future<(int, bool, String?)> decodeInvoice(String invoice) async {
    // TODO: implement decodeInvoice
    final decoded = await DecodedInvoice.fromString(
      s: invoice,
      boltzUrl: _httpsUrl,
    );
    // convert decoded.msats to sats by dividing by 1000 and rounding down
    final sats = (decoded.msats ~/ BigInt.from(1000)).toInt();
    return (sats, decoded.isExpired, decoded.bip21);
  }
}
