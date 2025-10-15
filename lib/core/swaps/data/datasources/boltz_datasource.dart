import 'dart:async';

import 'package:bb_mobile/core/swaps/data/datasources/boltz_storage_datasource.dart';
import 'package:bb_mobile/core/swaps/data/models/swap_model.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart' as swap_entity;
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:boltz/boltz.dart';

class BoltzDatasource {
  final String _baseUrl;
  late String _httpsUrl;

  late BoltzWebSocket _boltzWebSocket;
  final BoltzStorageDatasource _boltzStore;

  final StreamController<SwapModel> _swapUpdatesController =
      StreamController<SwapModel>.broadcast();

  ReverseFeesAndLimits? _reverseFeesAndLimits;
  SubmarineFeesAndLimits? _submarineFeesAndLimits;
  ChainFeesAndLimits? _chainFeesAndLimits;

  BoltzDatasource({
    String url = ApiServiceConstants.boltzMainnetUrlPath,
    required BoltzStorageDatasource boltzStore,
  }) : _baseUrl = url,
       _boltzStore = boltzStore {
    _httpsUrl = 'https://$_baseUrl';
    _initializeBoltzWebSocket();
  }

  Future<void> updateFees({required swap_entity.SwapType swapType}) async {
    final allFees = Fees(boltzUrl: _httpsUrl);
    switch (swapType) {
      case swap_entity.SwapType.lightningToBitcoin:
      case swap_entity.SwapType.lightningToLiquid:
        _reverseFeesAndLimits = await allFees.reverse();
      case swap_entity.SwapType.bitcoinToLightning:
      case swap_entity.SwapType.liquidToLightning:
        _submarineFeesAndLimits = await allFees.submarine();
      case swap_entity.SwapType.bitcoinToLiquid:
      case swap_entity.SwapType.liquidToBitcoin:
        _chainFeesAndLimits = await allFees.chain();
    }
  }

  BoltzStorageDatasource get storage => _boltzStore;

  Stream<SwapModel> get swapUpdatesStream => _swapUpdatesController.stream;

  StreamController<SwapModel> get swapUpdatesController =>
      _swapUpdatesController;

  Future<swap_entity.SwapFees> getSwapFees(swap_entity.SwapType type) async {
    if (type.isReverse && _reverseFeesAndLimits == null) {
      await updateFees(swapType: type);
    }
    if (type.isSubmarine && _submarineFeesAndLimits == null) {
      await updateFees(swapType: type);
    }
    if (!type.isChain && !type.isSubmarine && _chainFeesAndLimits == null) {
      await updateFees(swapType: type);
    }
    switch (type) {
      case swap_entity.SwapType.lightningToBitcoin:
        final fees = _reverseFeesAndLimits!;
        return swap_entity.SwapFees(
          boltzPercent: fees.btcFees.percentage as double?,
          lockupFee: fees.btcFees.minerFees.lockup.toInt() as int?,
          claimFee: fees.btcFees.minerFees.claim.toInt() as int?,
        );
      case swap_entity.SwapType.lightningToLiquid:
        final fees = _reverseFeesAndLimits!;
        return swap_entity.SwapFees(
          boltzPercent: fees.lbtcFees.percentage as double?,
          lockupFee: fees.lbtcFees.minerFees.lockup.toInt() as int?,
          claimFee: fees.lbtcFees.minerFees.claim.toInt() as int?,
        );
      case swap_entity.SwapType.bitcoinToLightning:
        final fees = _submarineFeesAndLimits!;
        return swap_entity.SwapFees(
          boltzPercent: fees.btcFees.percentage as double?,
          lockupFee: fees.btcFees.minerFees.toInt() as int?,
          claimFee: fees.btcFees.minerFees.toInt() as int?,
        );
      case swap_entity.SwapType.liquidToLightning:
        final fees = _submarineFeesAndLimits!;
        return swap_entity.SwapFees(
          boltzPercent: fees.lbtcFees.percentage as double?,
          lockupFee: fees.lbtcFees.minerFees.toInt() as int?,
          claimFee: fees.lbtcFees.minerFees.toInt() as int?,
        );
      case swap_entity.SwapType.bitcoinToLiquid:
        final fees = _chainFeesAndLimits!;
        return swap_entity.SwapFees(
          boltzPercent: fees.lbtcFees.percentage as double?,
          lockupFee: fees.lbtcFees.server.toInt() as int?,
          claimFee: fees.lbtcFees.userClaim.toInt() as int?,
        );
      case swap_entity.SwapType.liquidToBitcoin:
        final fees = _chainFeesAndLimits!;
        return swap_entity.SwapFees(
          boltzPercent: fees.btcFees.percentage as double?,
          lockupFee: fees.btcFees.server.toInt() as int?,
          claimFee: fees.btcFees.userClaim.toInt() as int?,
        );
    }
  }

  // REVERSE SWAPS
  Future<SwapModel> createBtcReverseSwap({
    required String walletId,
    required String mnemonic,
    required int index,
    required int outAmount,
    required bool isTestnet,
    required String electrumUrl,
    required String magicRouteHintAddress,
    String? description,
  }) async {
    try {
      if (_reverseFeesAndLimits == null) {
        await updateFees(swapType: swap_entity.SwapType.lightningToBitcoin);
      }
      final reverseFees = _reverseFeesAndLimits!;
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
        receiveWalletId: walletId,
        invoice: btcLnSwap.invoice,
        boltzFees:
            (reverseFees.btcFees.percentage * outAmount / 100).ceil() as int?,
        lockupFees: reverseFees.btcFees.minerFees.lockup.toInt() as int?,
        claimFees: reverseFees.btcFees.minerFees.claim.toInt() as int?,
        receiveAddress: magicRouteHintAddress,
      );
      await _boltzStore.store(swapModel);
      subscribeToSwaps([swapModel.id]);
      return swapModel;
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<String> claimBtcReverseSwap({
    required String swapId,
    required String claimAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    try {
      final btcLnSwap = await _boltzStore.fetchBtcLnSwap(swapId);

      return btcLnSwap.claim(
        outAddress: claimAddress,
        minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
        tryCooperate: tryCooperate,
      );
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<SwapModel> createLBtcReverseSwap({
    required String walletId,
    required String mnemonic,
    required int index,
    required int outAmount,
    required bool isTestnet,
    required String electrumUrl,
    required String magicRouteHintAddress,
    String? description,
  }) async {
    try {
      if (_reverseFeesAndLimits == null) {
        await updateFees(swapType: swap_entity.SwapType.lightningToLiquid);
      }
      final reverseFees = _reverseFeesAndLimits!;
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
        receiveWalletId: walletId,
        invoice: lbtcLnSwap.invoice,
        boltzFees:
            (reverseFees.lbtcFees.percentage * outAmount / 100).ceil() as int?,
        lockupFees: reverseFees.lbtcFees.minerFees.lockup.toInt() as int?,
        claimFees: reverseFees.lbtcFees.minerFees.claim.toInt() as int?,
        receiveAddress: magicRouteHintAddress,
      );

      await _boltzStore.store(swapModel);
      subscribeToSwaps([swapModel.id]);

      return swapModel;
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<String> claimLBtcReverseSwap({
    required String swapId,
    required String claimAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    try {
      final lbtcLnSwap = await _boltzStore.fetchLbtcLnSwap(swapId);

      return lbtcLnSwap.claim(
        outAddress: claimAddress,
        minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
        tryCooperate: tryCooperate,
      );
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<String> broadcastBtcLnSwap({
    required String swapId,
    required String signedTxHex,
    required bool broadcastViaBoltz,
  }) async {
    try {
      final btcLnSwap = await _boltzStore.fetchBtcLnSwap(swapId);

      return broadcastViaBoltz
          ? btcLnSwap.broadcastLocal(signedHex: signedTxHex)
          : btcLnSwap.broadcastBoltz(signedHex: signedTxHex);
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<String> broadcastLbtcLnSwap({
    required String swapId,
    required String signedTxHex,
    required bool broadcastViaBoltz,
  }) async {
    try {
      final lbtcLnSwap = await _boltzStore.fetchLbtcLnSwap(swapId);

      return broadcastViaBoltz
          ? lbtcLnSwap.broadcastLocal(signedHex: signedTxHex)
          : lbtcLnSwap.broadcastBoltz(signedHex: signedTxHex);
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<SwapModel> createBtcSubmarineSwap({
    required String walletId,
    required String mnemonic,
    required int index,
    required String invoice,
    required bool isTestnet,
    required String electrumUrl,
  }) async {
    try {
      if (_submarineFeesAndLimits == null) {
        await updateFees(swapType: swap_entity.SwapType.bitcoinToLightning);
      }
      final submarineFees = _submarineFeesAndLimits!;
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
        sendWalletId: walletId,
        invoice: invoice,
        paymentAddress: btcLnSwap.scriptAddress,
        paymentAmount: btcLnSwap.outAmount.toInt(),
        boltzFees:
            (submarineFees.btcFees.percentage *
                        (btcLnSwap.outAmount.toInt()) /
                        100)
                    .ceil()
                as int?,
        lockupFees: submarineFees.btcFees.minerFees.toInt() as int?,
        claimFees: submarineFees.btcFees.minerFees.toInt() as int?,
      );
      await _boltzStore.store(swapModel);
      subscribeToSwaps([swapModel.id]);

      return swapModel;
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<SwapModel> createLbtcSubmarineSwap({
    required String walletId,
    required String mnemonic,
    required int index,
    required String invoice,
    required bool isTestnet,
    required String electrumUrl,
  }) async {
    try {
      if (_submarineFeesAndLimits == null) {
        await updateFees(swapType: swap_entity.SwapType.liquidToLightning);
      }
      final submarineFees = _submarineFeesAndLimits!;
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
        sendWalletId: walletId,
        invoice: invoice,
        paymentAddress: lbtcLnSwap.scriptAddress,
        paymentAmount: lbtcLnSwap.outAmount.toInt(),
        boltzFees:
            (submarineFees.lbtcFees.percentage *
                        (lbtcLnSwap.outAmount.toInt()) /
                        100)
                    .ceil()
                as int?,
        lockupFees: submarineFees.lbtcFees.minerFees.toInt() as int?,
        claimFees: submarineFees.lbtcFees.minerFees.toInt() as int?,
      );

      await _boltzStore.store(swapModel);
      subscribeToSwaps([swapModel.id]);

      return swapModel;
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<void> coopSignBtcSubmarineSwap({required String swapId}) async {
    try {
      final btcLnSwap = await _boltzStore.fetchBtcLnSwap(swapId);
      return btcLnSwap.coopCloseSubmarine();
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<void> coopSignLbtcSubmarineSwap({required String swapId}) async {
    try {
      final lbtcLnSwap = await _boltzStore.fetchLbtcLnSwap(swapId);
      await lbtcLnSwap.coopCloseSubmarine();
      return;
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<String> refundBtcSubmarineSwap({
    required String swapId,
    required String refundAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    try {
      final btcLnSwap = await _boltzStore.fetchBtcLnSwap(swapId);
      return btcLnSwap.refund(
        outAddress: refundAddress,
        minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
        tryCooperate: tryCooperate,
      );
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<String> refundLbtcSubmarineSwap({
    required String swapId,
    required String refundAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    try {
      final lbtcLnSwap = await _boltzStore.fetchLbtcLnSwap(swapId);
      log.info(lbtcLnSwap.id);
      log.info(lbtcLnSwap.network.toString());
      return lbtcLnSwap.refund(
        outAddress: refundAddress,
        minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
        tryCooperate: tryCooperate,
      );
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
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
    try {
      if (_chainFeesAndLimits == null) {
        await updateFees(swapType: swap_entity.SwapType.bitcoinToLiquid);
      }
      final chainFees = _chainFeesAndLimits!;
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
        paymentAddress: chainSwap.scriptAddress,
        paymentAmount: chainSwap.outAmount.toInt(),
        receiveAddress: externalRecipientAddress,
        boltzFees:
            (chainFees.lbtcFees.percentage * amountSat / 100).ceil() as int?,
        lockupFees: chainFees.lbtcFees.server.toInt() as int?,
        claimFees: chainFees.lbtcFees.userClaim.toInt() as int?,
      );
      await _boltzStore.store(swapModel);
      subscribeToSwaps([swapModel.id]);
      return swapModel;
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
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
    try {
      if (_chainFeesAndLimits == null) {
        await updateFees(swapType: swap_entity.SwapType.liquidToBitcoin);
      }
      final chainFees = _chainFeesAndLimits!;

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
        paymentAddress: chainSwap.scriptAddress,
        paymentAmount: chainSwap.outAmount.toInt(),
        receiveAddress: externalRecipientAddress,
        boltzFees:
            (chainFees.btcFees.percentage * amountSat / 100).ceil() as int?,
        lockupFees: chainFees.btcFees.server.toInt() as int?,
        claimFees: chainFees.btcFees.userClaim.toInt() as int?,
      );
      await _boltzStore.store(swapModel);
      subscribeToSwaps([swapModel.id]);

      return swapModel;
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<String> broadcastChainSwapRefund({
    required String swapId,
    required String signedTxHex,
    required bool broadcastViaBoltz,
  }) async {
    try {
      final chainSwap = await _boltzStore.fetchChainSwap(swapId);
      return broadcastViaBoltz
          ? chainSwap.broadcastLocal(
            signedHex: signedTxHex,
            kind: SwapTxKind.refund,
          )
          : chainSwap.broadcastBoltz(
            signedHex: signedTxHex,
            kind: SwapTxKind.refund,
          );
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<String> claimBtcToLbtcChainSwap({
    required String swapId,
    required String claimLiquidAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    try {
      final chainSwap = await _boltzStore.fetchChainSwap(swapId);
      return await chainSwap.claim(
        outAddress: claimLiquidAddress,
        minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
        tryCooperate: tryCooperate,
      );
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<String> claimLbtcToBtcChainSwap({
    required String swapId,
    required String claimBitcoinAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    try {
      final chainSwap = await _boltzStore.fetchChainSwap(swapId);
      return await chainSwap.claim(
        outAddress: claimBitcoinAddress,
        minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
        tryCooperate: tryCooperate,
      );
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<String> broadcastChainSwapClaim({
    required String swapId,
    required String signedTxHex,
    required bool broadcastViaBoltz,
  }) async {
    try {
      final chainSwap = await _boltzStore.fetchChainSwap(swapId);
      return broadcastViaBoltz
          ? chainSwap.broadcastLocal(
            signedHex: signedTxHex,
            kind: SwapTxKind.claim,
          )
          : chainSwap.broadcastBoltz(
            signedHex: signedTxHex,
            kind: SwapTxKind.claim,
          );
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<String> refundBtcToLbtcChainSwap({
    required String swapId,
    required String refundBitcoinAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    try {
      final chainSwap = await _boltzStore.fetchChainSwap(swapId);
      return await chainSwap.refund(
        refundAddress: refundBitcoinAddress,
        minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
        tryCooperate: tryCooperate,
      );
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<String> refundLbtcToBtcChainSwap({
    required String swapId,
    required String refundLiquidAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    try {
      final chainSwap = await _boltzStore.fetchChainSwap(swapId);
      return await chainSwap.refund(
        refundAddress: refundLiquidAddress,
        minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
        tryCooperate: tryCooperate,
      );
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<(int, int)> getBtcReverseSwapLimits() async {
    if (_reverseFeesAndLimits == null) {
      await updateFees(swapType: swap_entity.SwapType.lightningToBitcoin);
    }
    final reverse = _reverseFeesAndLimits!;
    return (
      reverse.btcLimits.minimal.toInt(),
      reverse.btcLimits.maximal.toInt(),
    );
  }

  Future<(int, int)> getLbtcReverseSwapLimits() async {
    if (_reverseFeesAndLimits == null) {
      await updateFees(swapType: swap_entity.SwapType.lightningToLiquid);
    }
    final reverse = _reverseFeesAndLimits!;
    return (
      reverse.lbtcLimits.minimal.toInt(),
      reverse.lbtcLimits.maximal.toInt(),
    );
  }

  Future<(int, int)> getBtcSubmarineSwapLimits() async {
    if (_submarineFeesAndLimits == null) {
      await updateFees(swapType: swap_entity.SwapType.bitcoinToLightning);
    }
    final submarine = _submarineFeesAndLimits!;
    return (
      submarine.btcLimits.minimal.toInt(),
      submarine.btcLimits.maximal.toInt(),
    );
  }

  Future<(int, int)> getLbtcSubmarineSwapLimits() async {
    if (_submarineFeesAndLimits == null) {
      await updateFees(swapType: swap_entity.SwapType.liquidToLightning);
    }
    final submarine = _submarineFeesAndLimits!;
    return (
      submarine.lbtcLimits.minimal.toInt(),
      submarine.lbtcLimits.maximal.toInt(),
    );
  }

  Future<(int, int)> getBtcToLbtcChainSwapLimits() async {
    if (_chainFeesAndLimits == null) {
      await updateFees(swapType: swap_entity.SwapType.bitcoinToLiquid);
    }
    final chain = _chainFeesAndLimits!;
    return (chain.btcLimits.minimal.toInt(), chain.btcLimits.maximal.toInt());
  }

  Future<(int, int)> getLbtcToBtcChainSwapLimits() async {
    if (_chainFeesAndLimits == null) {
      await updateFees(swapType: swap_entity.SwapType.liquidToBitcoin);
    }
    final chain = _chainFeesAndLimits!;
    return (chain.lbtcLimits.minimal.toInt(), chain.lbtcLimits.maximal.toInt());
  }

  Future<int> getLbtLnRefundTxSize({
    required String swapId,
    bool isCooperative = true,
  }) async {
    final lnSwap = await _boltzStore.fetchLbtcLnSwap(swapId);
    final size = await lnSwap.refundTxSize(isCooperative: isCooperative);
    return size.toInt();
  }

  Future<int> getBtcLnRefundTxSize({
    required String swapId,
    bool isCooperative = true,
  }) async {
    final lnSwap = await _boltzStore.fetchBtcLnSwap(swapId);
    final size = await lnSwap.refundTxSize(isCooperative: isCooperative);
    return size.toInt();
  }

  Future<int> getChainRefundTxSize({
    required String swapId,
    required String refundAddress,
    bool isCooperative = true,
  }) async {
    final chainSwap = await _boltzStore.fetchChainSwap(swapId);
    final size = await chainSwap.refundTxSize(
      refundAddress: refundAddress,
      tryCooperate: isCooperative,
    );
    return size.toInt();
  }

  // Future<int> getChainTxSize({
  //   required String swapId,
  //   bool isCooperative = true,
  // }) async {
  //   final chainSwap = await _boltzStore.fetchChainSwap(swapId);
  //   final size = await chainSwap.txSize(isCooperative: isCooperative);
  //   return size.toInt();
  // }

  void _initializeBoltzWebSocket() {
    try {
      _boltzWebSocket = BoltzWebSocket.create(_baseUrl);

      _boltzWebSocket.stream.listen(
        (event) async {
          final swapId = event.id;
          final boltzStatus = event.status;
          try {
            final swapModel = await _boltzStore.fetch(swapId);
            if (swapModel == null) {
              log.info('No swap found for id: $swapId');
              return;
            }
            // Check if swap is already in terminal state
            final swapCompleted =
                swapModel.status == swap_entity.SwapStatus.completed.name;
            final isLnSwap =
                swapModel is LnSendSwapModel || swapModel is LnReceiveSwapModel;
            final chainSwapCompleted =
                swapModel is ChainSwapModel &&
                (swapModel.receiveTxid != null) &&
                swapCompleted;
            final swapFailed =
                swapModel.status == swap_entity.SwapStatus.failed.name;
            final swapExpired =
                swapModel.status == swap_entity.SwapStatus.expired.name;

            if ((swapCompleted && isLnSwap) ||
                swapFailed ||
                swapExpired ||
                chainSwapCompleted) {
              // Unsubscribe from the swap if it's in a terminal state
              _swapUpdatesController.add(swapModel);
              return unsubscribeToSwaps([swapId]);
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
                if (swapModel is LnSendSwapModel) {
                  updatedSwapModel = swapModel.copyWith(
                    completionTime: DateTime.now().millisecondsSinceEpoch,
                  );
                }
                // we want the completion time to be set when the invoice is paid
                // the swap is still not completed as we need to coop close
                return;

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
                    completionTime: DateTime.now().millisecondsSinceEpoch,
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
                if (swapModel is ChainSwapModel) {
                  updatedSwapModel = swapModel.copyWith(
                    status: swap_entity.SwapStatus.paid.name,
                  );
                }
                if (swapModel is LnSendSwapModel) {
                  updatedSwapModel = swapModel.copyWith(
                    status: swap_entity.SwapStatus.paid.name,
                  );
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
                if (swapModel is ChainSwapModel) {
                  if (swapModel.receiveTxid == null) {
                    updatedSwapModel = swapModel.copyWith(
                      status: swap_entity.SwapStatus.claimable.name,
                    );
                  }
                }
                if (swapModel is LnSendSwapModel) {
                  updatedSwapModel = swapModel.copyWith(
                    status: swap_entity.SwapStatus.completed.name,
                    completionTime: DateTime.now().millisecondsSinceEpoch,
                  );
                }

              case SwapStatus.txnRefunded:
                // Check if this swap needs to be refunded (no refundTxid)
                if (swapModel is ChainSwapModel ||
                    swapModel is LnSendSwapModel) {
                  final refunded =
                      swapModel is ChainSwapModel
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
                  final hasSentFunds =
                      swapModel is ChainSwapModel
                          ? swapModel.sendTxid != null
                          : (swapModel as LnSendSwapModel).sendTxid != null;

                  final hasRefunded =
                      swapModel is ChainSwapModel
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
                  final hasSentFunds =
                      swapModel is ChainSwapModel
                          ? swapModel.sendTxid != null
                          : (swapModel as LnSendSwapModel).sendTxid != null;

                  final hasRefunded =
                      swapModel is ChainSwapModel
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
                  final hasRefunded =
                      swapModel is ChainSwapModel
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
                  final hasSentFunds =
                      swapModel is ChainSwapModel
                          ? swapModel.sendTxid != null
                          : (swapModel as LnSendSwapModel).sendTxid != null;

                  final hasRefunded =
                      swapModel is ChainSwapModel
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
                  updatedSwapModel = swapModel.copyWith(
                    status: swap_entity.SwapStatus.paid.name,
                  );
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
              log.info(
                'Updated swap $swapId from ${swapModel.status} to ${updatedSwapModel.status}',
              );
              _swapUpdatesController.add(updatedSwapModel);
            }
          } catch (e) {
            log.info('Error processing swap status update: $e');
          }
        },
        onError: (error) {
          log.info('Boltz WebSocket error: $error');
          _swapUpdatesController.addError(error.toString());
        },
        onDone: () {},
      );

      log.info('Started Boltz WebSocket');
    } catch (e) {
      log.info('Error initializing BoltzWebSocket: $e');
      // Don't rethrow here to allow for graceful recovery
    }
  }

  Future<void> reconnect() async {
    try {
      log.info('Attempting to reconnect to Boltz WebSocket...');
      resetStream();
    } catch (e) {
      log.info('Failed to reconnect: $e');
    }
  }

  void resetStream() {
    try {
      _boltzWebSocket.dispose();
      log.info('Boltz WebSocket connection closed');
    } catch (e) {
      log.info('Error disposing WebSocket: $e');
    }
    // _swapUpdatesController.close();
    _initializeBoltzWebSocket();
  }

  void subscribeToSwaps(List<String> swapIds) {
    try {
      _boltzWebSocket.subscribe(swapIds);
    } catch (e) {
      log.info('Error subscribing to swaps: $e');
    }
  }

  void unsubscribeToSwaps(List<String> swapIds) {
    try {
      _boltzWebSocket.unsubscribe(swapIds);
    } catch (e) {
      log.info('Error unsubscribing from swaps: $e');
    }
  }

  Future<(int, bool, String?)> decodeInvoice(String invoice) async {
    try {
      final decoded = await DecodedInvoice.fromString(
        s: invoice,
        boltzUrl: _httpsUrl,
      );
      // convert decoded.msats to sats by dividing by 1000 and rounding down
      final sats = (decoded.msats ~/ BigInt.from(1000)).toInt();
      return (sats, decoded.isExpired, decoded.bip21);
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<void> fromBtcLnSwapObjectMigration(
    BtcLnSwap swap,
    String? receiveWalletId,
    String? sendWalletId,
    String? lockupTxid,
    String? claimAddress,
  ) async {
    final fees = Fees(boltzUrl: _httpsUrl);
    final reverseFees = await fees.reverse();
    final submarineFees = await fees.submarine();
    final swapType =
        swap.kind == SwapType.reverse
            ? swap_entity.SwapType.lightningToBitcoin
            : swap_entity.SwapType.bitcoinToLightning;
    if (swapType == swap_entity.SwapType.lightningToBitcoin) {
      if (receiveWalletId == null) {
        throw 'Receive wallet ID is required for lightning to bitcoin swaps';
      }
      final swapModel = SwapModel.lnReceive(
        id: swap.id,
        status: swap_entity.SwapStatus.pending.name,
        type: swapType.name,
        keyIndex: swap.keyIndex.toInt(),
        receiveWalletId: receiveWalletId,
        invoice: swap.invoice,
        creationTime: DateTime.now().millisecondsSinceEpoch,
        boltzFees:
            (reverseFees.btcFees.percentage * swap.outAmount.toInt() / 100)
                    .ceil()
                as int?,
        lockupFees: reverseFees.btcFees.minerFees.lockup.toInt() as int?,
        claimFees: reverseFees.btcFees.minerFees.claim.toInt() as int?,
        receiveAddress: claimAddress,
      );
      await _boltzStore.storeBtcLnSwap(swap);
      await _boltzStore.store(swapModel);
    }
    if (swapType == swap_entity.SwapType.bitcoinToLightning) {
      if (sendWalletId == null) {
        throw 'Send wallet ID is required for lightning to bitcoin swaps';
      }
      final swapModel = SwapModel.lnSend(
        id: swap.id,
        status: swap_entity.SwapStatus.pending.name,
        type: swapType.name,
        keyIndex: swap.keyIndex.toInt(),
        sendWalletId: sendWalletId,
        invoice: swap.invoice,
        creationTime: DateTime.now().millisecondsSinceEpoch,
        paymentAddress: swap.scriptAddress,
        paymentAmount: swap.outAmount.toInt(),
        sendTxid: lockupTxid,
        boltzFees:
            (submarineFees.btcFees.percentage * (swap.outAmount.toInt()) / 100)
                    .ceil()
                as int?,
        lockupFees: submarineFees.btcFees.minerFees.toInt() as int?,
        claimFees: submarineFees.btcFees.minerFees.toInt() as int?,
      );
      await _boltzStore.storeBtcLnSwap(swap);
      await _boltzStore.store(swapModel);
    }
  }

  Future<void> fromLbtcLnSwapObjectMigration(
    LbtcLnSwap swap,
    String? receiveWalletId,
    String? sendWalletId,
    String? lockupTxid,
    String? claimAddress,
  ) async {
    final fees = Fees(boltzUrl: _httpsUrl);
    final reverseFees = await fees.reverse();
    final submarineFees = await fees.submarine();
    final swapType =
        swap.kind == SwapType.reverse
            ? swap_entity.SwapType.lightningToLiquid
            : swap_entity.SwapType.liquidToLightning;
    if (swapType == swap_entity.SwapType.lightningToLiquid) {
      if (receiveWalletId == null) {
        throw 'Receive wallet ID is required for lightning to liquid swaps';
      }
      final swapModel = SwapModel.lnReceive(
        id: swap.id,
        status: swap_entity.SwapStatus.pending.name,
        type: swapType.name,
        keyIndex: swap.keyIndex.toInt(),
        receiveWalletId: receiveWalletId,
        invoice: swap.invoice,
        creationTime: DateTime.now().millisecondsSinceEpoch,
        boltzFees:
            (reverseFees.lbtcFees.percentage * swap.outAmount.toInt() / 100)
                    .ceil()
                as int?,
        lockupFees: reverseFees.lbtcFees.minerFees.lockup.toInt() as int?,
        claimFees: reverseFees.lbtcFees.minerFees.claim.toInt() as int?,
        receiveAddress: claimAddress,
      );
      await _boltzStore.storeLbtcLnSwap(swap);
      await _boltzStore.store(swapModel);
    }
    if (swapType == swap_entity.SwapType.liquidToLightning) {
      if (sendWalletId == null) {
        throw 'Send wallet ID is required for lightning to liquid swaps';
      }
      final swapModel = SwapModel.lnSend(
        id: swap.id,
        status: swap_entity.SwapStatus.pending.name,
        type: swapType.name,
        keyIndex: swap.keyIndex.toInt(),
        sendWalletId: sendWalletId,
        invoice: swap.invoice,
        creationTime: DateTime.now().millisecondsSinceEpoch,
        paymentAddress: swap.scriptAddress,
        paymentAmount: swap.outAmount.toInt(),
        sendTxid: lockupTxid,
        boltzFees:
            (submarineFees.lbtcFees.percentage * (swap.outAmount.toInt()) / 100)
                    .ceil()
                as int?,
        lockupFees: submarineFees.lbtcFees.minerFees.toInt() as int?,
        claimFees: submarineFees.lbtcFees.minerFees.toInt() as int?,
      );
      await _boltzStore.storeLbtcLnSwap(swap);
      await _boltzStore.store(swapModel);
    }
  }

  Future<void> fromChainSwapObjectMigration(
    ChainSwap swap,
    String sendWalletId,
    String receiveWalletId,
    bool isReceiveWalletExternal,
    String? lockupTxid,
  ) async {
    final fees = Fees(boltzUrl: _httpsUrl);
    final chainFees = await fees.chain();
    final swapType =
        swap.direction == ChainSwapDirection.lbtcToBtc
            ? swap_entity.SwapType.liquidToBitcoin
            : swap_entity.SwapType.bitcoinToLiquid;
    switch (swapType) {
      case swap_entity.SwapType.liquidToBitcoin:
        final swapModel = SwapModel.chain(
          id: swap.id,
          status: swap_entity.SwapStatus.pending.name,
          type: swapType.name,
          keyIndex: swap.claimIndex.toInt(),
          creationTime: DateTime.now().millisecondsSinceEpoch,
          sendWalletId: sendWalletId,
          paymentAddress: swap.scriptAddress,
          paymentAmount: swap.outAmount.toInt(),
          sendTxid: lockupTxid,
          receiveWalletId:
              isReceiveWalletExternal == false ? receiveWalletId : null,
          receiveAddress:
              isReceiveWalletExternal == true ? receiveWalletId : null,
          boltzFees:
              (chainFees.btcFees.percentage * swap.outAmount.toInt() / 100)
                      .ceil()
                  as int?,
          lockupFees:
              chainFees.lbtcFees.userLockup.toInt() +
              chainFees.lbtcFees.server.toInt() +
              chainFees.btcFees.server.toInt(),
          claimFees: chainFees.btcFees.userClaim.toInt() as int?,
        );
        await _boltzStore.storeChainSwap(swap);
        await _boltzStore.store(swapModel);
      case swap_entity.SwapType.bitcoinToLiquid:
        final swapModel = SwapModel.chain(
          id: swap.id,
          status: swap_entity.SwapStatus.pending.name,
          type: swapType.name,
          keyIndex: swap.claimIndex.toInt(),
          creationTime: DateTime.now().millisecondsSinceEpoch,
          sendWalletId: sendWalletId,
          paymentAddress: swap.scriptAddress,
          paymentAmount: swap.outAmount.toInt(),
          sendTxid: lockupTxid,
          receiveWalletId:
              isReceiveWalletExternal == false ? receiveWalletId : null,
          receiveAddress:
              isReceiveWalletExternal == true ? receiveWalletId : null,
          boltzFees:
              (chainFees.btcFees.percentage * swap.outAmount.toInt() / 100)
                      .ceil()
                  as int?,
          lockupFees:
              chainFees.btcFees.userLockup.toInt() +
              chainFees.btcFees.server.toInt() +
              chainFees.lbtcFees.server.toInt(),
          claimFees: chainFees.lbtcFees.userClaim.toInt() as int?,
        );
        await _boltzStore.storeChainSwap(swap);
        await _boltzStore.store(swapModel);
      default:
        throw Exception('Invalid swap type');
    }
  }
}
