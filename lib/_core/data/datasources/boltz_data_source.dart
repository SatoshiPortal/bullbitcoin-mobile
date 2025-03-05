import 'dart:convert';

import 'package:bb_mobile/_core/data/datasources/boltz_storage_data_source.dart';
import 'package:bb_mobile/_core/data/models/swap_model.dart';
import 'package:bb_mobile/_core/domain/entities/swap.dart' as swap_entity;
import 'package:bb_mobile/_utils/constants.dart';
import 'package:boltz/boltz.dart';

abstract class BoltzDataSource {
  // Reverse Swaps
  Future<(int, int)> getBtcReverseSwapLimits();
  Future<(int, int)> getLbtcReverseSwapLimits();

  Future<SwapModel> createBtcReverseSwap({
    required String walletId,
    required String mnemonic,
    required int index,
    required int outAmount,
    required bool isTestnet,
    required String electrumUrl,
  });

  /// Returns a signed tx hex which needs to be broadcasted
  Future<String> claimBtcReverseSwap({
    required String swapId,
    required String claimAddress,
    required int absoluteFees,
    required bool tryCooperate,
  });
  Future<String> broadcastBtcLnSwap({
    required String swapId,
    required String signedTxHex,
    required bool broadcastViaBoltz,
  });
  Future<SwapModel> createLBtcReverseSwap({
    required String walletId,
    required String mnemonic,
    required int index,
    required int outAmount,
    required bool isTestnet,
    required String electrumUrl,
  });

  /// Returns a signed tx hex which needs to be broadcasted
  Future<String> claimLBtcReverseSwap({
    required String swapId,
    required String claimAddress,
    required int absoluteFees,
    required bool tryCooperate,
  });
  Future<String> broadcastLbtcLnSwap({
    required String swapId,
    required String signedTxHex,
    required bool broadcastViaBoltz,
  });
  // Submarine Swaps
  Future<(int, int)> getBtcSubmarineSwapLimits();
  Future<(int, int)> getLbtcSubmarineSwapLimits();

  Future<SwapModel> createBtcSubmarineSwap({
    required String walletId,
    required String mnemonic,
    required int index,
    required String invoice,
    required bool isTestnet,
    required String electrumUrl,
  });
  Future<void> coopSignBtcSubmarineSwap({required String swapId});
  // TODO: add function to get invoice preimage
  /// Returns a signed tx hex which needs to be broadcasted
  Future<String> refundBtcSubmarineSwap({
    required String swapId,
    required String refundAddress,
    required int absoluteFees,
    required bool tryCooperate,
  });
  Future<SwapModel> createLbtcSubmarineSwap({
    required String walletId,
    required String mnemonic,
    required int index,
    required String invoice,
    required bool isTestnet,
    required String electrumUrl,
  });
  Future<void> coopSignLbtcSubmarineSwap({required String swapId});
  // TODO: add function to get invoice preimage
  /// Returns a signed tx hex which needs to be broadcasted
  Future<String> refundLbtcSubmarineSwap({
    required String swapId,
    required String refundAddress,
    required int absoluteFees,
    required bool tryCooperate,
  });

  // Chain Swap
  Future<(int, int)> getBtcToLbtcChainSwapLimits();
  Future<(int, int)> getLbtcToBtcChainSwapLimits();

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
  });
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
  });

  /// Returns a signed tx hex which needs to be broadcasted
  Future<String> claimBtcToLbtcChainSwap({
    required String swapId,
    required String claimLiquidAddress,
    required String refundBitcoinAddress,
    required int absoluteFees,
    required bool tryCooperate,
  });

  /// Returns a signed tx hex which needs to be broadcasted
  Future<String> claimLbtcToBtcChainSwap({
    required String swapId,
    required String claimBitcoinAddress,
    required String refundLiquidAddress,
    required int absoluteFees,
    required bool tryCooperate,
  });
  Future<String> broadcastChainSwapClaim({
    required String swapId,
    required String signedTxHex,
    required bool broadcastViaBoltz,
  });

  /// Returns a signed tx hex which needs to be broadcasted
  Future<String> refundBtcToLbtcChainSwap({
    required String swapId,
    required String refundBitcoinAddress,
    required int absoluteFees,
    required bool tryCooperate,
  });

  /// Returns a signed tx hex which needs to be broadcasted
  Future<String> refundLbtcToBtcChainSwap({
    required String swapId,
    required String refundLiquidAddress,
    required int absoluteFees,
    required bool tryCooperate,
  });

  Future<String> broadcastChainSwapRefund({
    required String swapId,
    required String signedTxHex,
    required bool broadcastViaBoltz,
  });

  // Swap Actions
  Future<void> updateBtcLnSwapStatus({
    required String swapId,
    required String status,
  });
  Future<void> updateLbtcLnSwapStatus({
    required String swapId,
    required String status,
  });
  Future<void> updateChainSwapStatus({
    required String swapId,
    required String status,
  });
  // Websocket
  Stream<(String, String)> get stream;
  void initializBoltzWebSocket();
  void subscribeToSwaps(List<String> swapIds);
  void unsubscribeToSwaps(List<String> swapIds);
  void resetStream();
  // STORAGE
  BoltzStorageDataSourceImpl get storage;
}

class BoltzDataSourceImpl implements BoltzDataSource {
  final String _url;

  late BoltzWebSocket _boltzWebSocket;
  final BoltzStorageDataSourceImpl _boltzStore;

  BoltzDataSourceImpl({
    String url = ApiServiceConstants.boltzMainnetUrlPath,
    required BoltzStorageDataSourceImpl boltzStore,
  })  : _url = url,
        _boltzStore = boltzStore {
    initializBoltzWebSocket();
  }

  BoltzStorageDataSourceImpl get storage => _boltzStore;
  // REVERSE SWAPS

  @override
  Future<SwapModel> createBtcReverseSwap({
    required String walletId,
    required String mnemonic,
    required int index,
    required int outAmount,
    required bool isTestnet,
    required String electrumUrl,
  }) async {
    final fees = Fees(boltzUrl: _url);
    final reverseFees = await fees.reverse();
    final btcLnSwap = await BtcLnSwap.newReverse(
      mnemonic: mnemonic,
      index: BigInt.from(index),
      outAmount: BigInt.from(outAmount),
      network: isTestnet ? Chain.bitcoinTestnet : Chain.bitcoin,
      electrumUrl: electrumUrl,
      boltzUrl: _url,
    );
    await _boltzStore.storeBtcLnSwap(btcLnSwap);
    final swapModel = SwapModel(
      id: btcLnSwap.id,
      status: swap_entity.SwapStatus.pending.toString(),
      creationTime: DateTime.now().millisecondsSinceEpoch,
      type: swap_entity.SwapType.lightningToBitcoin.toString(),
      keyIndex: index,
      boltzFees: reverseFees.btcFees.percentage * outAmount ~/ 100,
      lockupFees: reverseFees.btcFees.minerFees.lockup.toInt(),
      claimFees: reverseFees.btcFees.minerFees.claim.toInt(),
      lnReceiveSwapJson: jsonEncode(
        swap_entity.LnReceiveSwapDetails(
          receiveWalletId: walletId,
          invoice: btcLnSwap.invoice,
        ).toJson(),
      ),
    );
    await _boltzStore.store(swapModel);
    return swapModel;
  }

  @override
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

  @override
  Future<SwapModel> createLBtcReverseSwap({
    required String walletId,
    required String mnemonic,
    required int index,
    required int outAmount,
    required bool isTestnet,
    required String electrumUrl,
  }) async {
    final fees = Fees(boltzUrl: _url);
    final reverseFees = await fees.reverse();
    final lbtcLnSwap = await LbtcLnSwap.newReverse(
      mnemonic: mnemonic,
      index: BigInt.from(index),
      outAmount: BigInt.from(outAmount),
      network: isTestnet ? Chain.liquidTestnet : Chain.liquid,
      electrumUrl: electrumUrl,
      boltzUrl: _url,
    );

    await _boltzStore.storeLbtcLnSwap(lbtcLnSwap);

    final swapModel = SwapModel(
      id: lbtcLnSwap.id,
      status: swap_entity.SwapStatus.pending.toString(),
      creationTime: DateTime.now().millisecondsSinceEpoch,
      type: swap_entity.SwapType.lightningToLiquid.toString(),
      keyIndex: index,
      boltzFees: reverseFees.lbtcFees.percentage * outAmount ~/ 100,
      lockupFees: reverseFees.lbtcFees.minerFees.lockup.toInt(),
      claimFees: reverseFees.lbtcFees.minerFees.claim.toInt(),
      lnReceiveSwapJson: jsonEncode(
        swap_entity.LnReceiveSwapDetails(
          receiveWalletId: walletId,
          invoice: lbtcLnSwap.invoice,
        ).toJson(),
      ),
    );

    await _boltzStore.store(swapModel);
    return swapModel;
  }

  @override
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

  @override
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

  @override
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

  // SUBMARINE SWAPS
  // @override
  // Future<swap_entity.SubmarineSwapFeesAndLimits>
  //     getSubmarineFeesAndLimits() async {
  //   final fees = Fees(boltzUrl: _url);
  //   final submarine = await fees.submarine();
  //   return submarine.toDomainEntity();
  // }

  @override
  Future<SwapModel> createBtcSubmarineSwap({
    required String walletId,
    required String mnemonic,
    required int index,
    required String invoice,
    required bool isTestnet,
    required String electrumUrl,
  }) async {
    final fees = Fees(boltzUrl: _url);
    final submarineFees = await fees.submarine();
    final btcLnSwap = await BtcLnSwap.newSubmarine(
      mnemonic: mnemonic,
      index: BigInt.from(index),
      invoice: invoice,
      network: isTestnet ? Chain.bitcoinTestnet : Chain.bitcoin,
      electrumUrl: electrumUrl,
      boltzUrl: _url,
    );

    await _boltzStore.storeBtcLnSwap(btcLnSwap);

    final swapModel = SwapModel(
      id: btcLnSwap.id,
      status: swap_entity.SwapStatus.pending.toString(),
      creationTime: DateTime.now().millisecondsSinceEpoch,
      type: swap_entity.SwapType.bitcoinToLightning.toString(),
      keyIndex: index,
      boltzFees: submarineFees.btcFees.percentage *
          (btcLnSwap.outAmount.toInt()) ~/
          100,
      lockupFees: submarineFees.btcFees.minerFees.toInt(),
      claimFees: submarineFees.btcFees.minerFees.toInt(),
      lnSendSwapJson: jsonEncode(
        swap_entity.LnSendSwapDetails(
          sendWalletId: walletId,
          invoice: invoice,
        ).toJson(),
      ),
    );

    await _boltzStore.store(swapModel);
    return swapModel;
  }

  @override
  Future<void> coopSignBtcSubmarineSwap({required String swapId}) async {
    final btcLnSwap = await _boltzStore.getBtcLnSwap(swapId);
    return btcLnSwap.coopCloseSubmarine();
  }

  @override
  Future<void> coopSignLbtcSubmarineSwap({required String swapId}) async {
    final lbtcLnSwap = await _boltzStore.getLbtcLnSwap(swapId);
    return lbtcLnSwap.coopCloseSubmarine();
  }

  @override
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

  @override
  Future<SwapModel> createLbtcSubmarineSwap({
    required String walletId,
    required String mnemonic,
    required int index,
    required String invoice,
    required bool isTestnet,
    required String electrumUrl,
  }) async {
    final fees = Fees(boltzUrl: _url);
    final submarineFees = await fees.submarine();
    final lbtcLnSwap = await LbtcLnSwap.newSubmarine(
      mnemonic: mnemonic,
      index: BigInt.from(index),
      invoice: invoice,
      network: isTestnet ? Chain.liquidTestnet : Chain.liquid,
      electrumUrl: electrumUrl,
      boltzUrl: _url,
    );

    await _boltzStore.storeLbtcLnSwap(lbtcLnSwap);

    final swapModel = SwapModel(
      id: lbtcLnSwap.id,
      status: swap_entity.SwapStatus.pending.toString(),
      creationTime: DateTime.now().millisecondsSinceEpoch,
      type: swap_entity.SwapType.liquidToLightning.toString(),
      keyIndex: index,
      boltzFees: submarineFees.lbtcFees.percentage *
          (lbtcLnSwap.outAmount.toInt()) ~/
          100,
      lockupFees: submarineFees.lbtcFees.minerFees.toInt(),
      claimFees: submarineFees.lbtcFees.minerFees.toInt(),
      lnSendSwapJson: jsonEncode(
        swap_entity.LnSendSwapDetails(
          sendWalletId: walletId,
          invoice: invoice,
        ).toJson(),
      ),
    );

    await _boltzStore.store(swapModel);
    return swapModel;
  }

  @override
  Future<String> refundLbtcSubmarineSwap({
    required String swapId,
    required String refundAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    final lbtcLnSwap = await _boltzStore.getLbtcLnSwap(swapId);
    return lbtcLnSwap.refund(
      outAddress: refundAddress,
      minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
      tryCooperate: tryCooperate,
    );
  }

  // // CHAIN SWAPS
  // @override
  // Future<ChainFeesAndLimits> getChainFeesAndLimits() async {
  //   final fees = Fees(boltzUrl: _url);
  //   final chain = await fees.chain();
  //   return chain;
  // }

  @override
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
    final fees = Fees(boltzUrl: _url);
    final chainFees = await fees.chain();
    final chainSwap = await ChainSwap.newSwap(
      mnemonic: mnemonic,
      index: BigInt.from(index),
      boltzUrl: _url,
      direction: ChainSwapDirection.btcToLbtc,
      amount: BigInt.from(amountSat),
      isTestnet: isTestnet,
      btcElectrumUrl: btcElectrumUrl,
      lbtcElectrumUrl: lbtcElectrumUrl,
    );

    await _boltzStore.storeChainSwap(chainSwap);

    final swapModel = SwapModel(
      id: chainSwap.id,
      status: swap_entity.SwapStatus.pending.toString(),
      creationTime: DateTime.now().millisecondsSinceEpoch,
      type: swap_entity.SwapType.bitcoinToLiquid.toString(),
      keyIndex: index,
      boltzFees: chainFees.lbtcFees.percentage * amountSat ~/ 100 +
          chainFees.lbtcFees.server.toInt(),
      lockupFees: chainFees.btcFees.userLockup.toInt(),
      claimFees: chainFees.lbtcFees.userClaim.toInt(),
      chainSwapJson: jsonEncode(
        swap_entity.ChainSwapDetails(
          sendWalletId: sendWalletId,
          receiveWalletId: receiveWalletId,
          receiveAddress: externalRecipientAddress,
        ).toJson(),
      ),
    );

    await _boltzStore.store(swapModel);
    return swapModel;
  }

  @override
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
    final fees = Fees(boltzUrl: _url);
    final chainFees = await fees.chain();

    final chainSwap = await ChainSwap.newSwap(
      mnemonic: mnemonic,
      index: BigInt.from(index),
      boltzUrl: _url,
      direction: ChainSwapDirection.lbtcToBtc,
      amount: BigInt.from(amountSat),
      isTestnet: isTestnet,
      btcElectrumUrl: btcElectrumUrl,
      lbtcElectrumUrl: lbtcElectrumUrl,
    );

    await _boltzStore.storeChainSwap(chainSwap);

    final swapModel = SwapModel(
      id: chainSwap.id,
      status: swap_entity.SwapStatus.pending.toString(),
      creationTime: DateTime.now().millisecondsSinceEpoch,
      type: swap_entity.SwapType.liquidToBitcoin.toString(),
      keyIndex: index,
      boltzFees: chainFees.btcFees.percentage * amountSat ~/ 100 +
          chainFees.btcFees.server.toInt(),
      lockupFees: chainFees.lbtcFees.userLockup.toInt(),
      claimFees: chainFees.btcFees.userClaim.toInt(),
      chainSwapJson: jsonEncode(
        swap_entity.ChainSwapDetails(
          sendWalletId: sendWalletId,
          receiveWalletId: receiveWalletId,
          receiveAddress: externalRecipientAddress,
        ).toJson(),
      ),
    );

    await _boltzStore.store(swapModel);
    return swapModel;
  }

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
  Future<void> updateBtcLnSwapStatus({
    required String swapId,
    required String status,
  }) async {
    final btcLnSwap = await _boltzStore.getBtcLnSwap(swapId);
    final action = await btcLnSwap.process(status: status);
    final swapModel = await _boltzStore.get(swapId);
    if (swapModel == null) {
      throw Exception('Swap not found');
    }
    switch (action) {
      case SwapAction.wait:
        return;
      case SwapAction.coopSign:
        const status = swap_entity.SwapStatus.canCoop;
        final updatedSwap = swapModel.copyWith(status: status.toString());
        await _boltzStore.store(updatedSwap);
        return;
      case SwapAction.claim:
        const status = swap_entity.SwapStatus.claimable;
        final updatedSwap = swapModel.copyWith(status: status.toString());
        await _boltzStore.store(updatedSwap);
        return;
      case SwapAction.refund:
        const status = swap_entity.SwapStatus.refundable;
        final updatedSwap = swapModel.copyWith(status: status.toString());
        await _boltzStore.store(updatedSwap);
        return;
      case SwapAction.close:
        return;
    }
  }

  @override
  Future<void> updateChainSwapStatus({
    required String swapId,
    required String status,
  }) async {
    final chainSwap = await _boltzStore.getChainSwap(swapId);
    final action = await chainSwap.process(status: status);
    final swapModel = await _boltzStore.get(swapId);
    if (swapModel == null) {
      throw Exception('Swap not found');
    }
    switch (action) {
      case SwapAction.wait:
        return;
      case SwapAction.coopSign:
        const status = swap_entity.SwapStatus.canCoop;
        final updatedSwap = swapModel.copyWith(status: status.toString());
        await _boltzStore.store(updatedSwap);
        return;
      case SwapAction.claim:
        const status = swap_entity.SwapStatus.claimable;
        final updatedSwap = swapModel.copyWith(status: status.toString());
        await _boltzStore.store(updatedSwap);
        return;
      case SwapAction.refund:
        const status = swap_entity.SwapStatus.refundable;
        final updatedSwap = swapModel.copyWith(status: status.toString());
        await _boltzStore.store(updatedSwap);
        return;
      case SwapAction.close:
        return;
    }
  }

  @override
  Future<void> updateLbtcLnSwapStatus({
    required String swapId,
    required String status,
  }) async {
    final lbtcLnSwap = await _boltzStore.getLbtcLnSwap(swapId);
    final action = await lbtcLnSwap.process(status: status);
    final swapModel = await _boltzStore.get(swapId);
    if (swapModel == null) {
      throw Exception('Swap not found');
    }
    switch (action) {
      case SwapAction.wait:
        return;
      case SwapAction.coopSign:
        const status = swap_entity.SwapStatus.canCoop;
        final updatedSwap = swapModel.copyWith(status: status.toString());
        await _boltzStore.store(updatedSwap);
        return;
      case SwapAction.claim:
        const status = swap_entity.SwapStatus.claimable;
        final updatedSwap = swapModel.copyWith(status: status.toString());
        await _boltzStore.store(updatedSwap);
        return;
      case SwapAction.refund:
        const status = swap_entity.SwapStatus.refundable;
        final updatedSwap = swapModel.copyWith(status: status.toString());
        await _boltzStore.store(updatedSwap);
        return;
      case SwapAction.close:
        return;
    }
  }

  Stream<(String, String)> get stream => _boltzWebSocket.stream.map(
        (swapStatus) => (swapStatus.id, swapStatus.status.toString()),
      );

  @override
  void resetStream() {
    _boltzWebSocket.dispose();
    initializBoltzWebSocket();
  }

  @override
  void subscribeToSwaps(List<String> swapIds) {
    _boltzWebSocket.subscribe(swapIds);
  }

  @override
  void unsubscribeToSwaps(List<String> swapIds) {
    _boltzWebSocket.unsubscribe(swapIds);
  }

  @override
  void initializBoltzWebSocket() {
    try {
      _boltzWebSocket = BoltzWebSocket.create(_url);
    } catch (e) {
      print('Error creating BoltzWebSocket: $e');
      rethrow;
    }
  }

  @override
  Future<(int, int)> getBtcReverseSwapLimits() async {
    final fees = Fees(boltzUrl: _url);
    final reverse = await fees.reverse();
    return (
      reverse.btcLimits.minimal.toInt(),
      reverse.btcLimits.maximal.toInt()
    );
  }

  @override
  Future<(int, int)> getLbtcReverseSwapLimits() async {
    final fees = Fees(boltzUrl: _url);
    final reverse = await fees.reverse();
    return (
      reverse.lbtcLimits.minimal.toInt(),
      reverse.lbtcLimits.maximal.toInt()
    );
  }

  @override
  Future<(int, int)> getBtcSubmarineSwapLimits() async {
    final fees = Fees(boltzUrl: _url);
    final submarine = await fees.submarine();
    return (
      submarine.btcLimits.minimal.toInt(),
      submarine.btcLimits.maximal.toInt()
    );
  }

  @override
  Future<(int, int)> getLbtcSubmarineSwapLimits() async {
    final fees = Fees(boltzUrl: _url);
    final submarine = await fees.submarine();
    return (
      submarine.lbtcLimits.minimal.toInt(),
      submarine.lbtcLimits.maximal.toInt()
    );
  }

  @override
  Future<(int, int)> getBtcToLbtcChainSwapLimits() async {
    final fees = Fees(boltzUrl: _url);
    final chain = await fees.chain();
    return (chain.btcLimits.minimal.toInt(), chain.btcLimits.maximal.toInt());
  }

  @override
  Future<(int, int)> getLbtcToBtcChainSwapLimits() async {
    final fees = Fees(boltzUrl: _url);
    final chain = await fees.chain();
    return (chain.lbtcLimits.minimal.toInt(), chain.lbtcLimits.maximal.toInt());
  }
}
