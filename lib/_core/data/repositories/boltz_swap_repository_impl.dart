import 'dart:math';

import 'package:bb_mobile/_core/data/datasources/boltz_api_data_source.dart';
import 'package:bb_mobile/_core/data/datasources/boltz_storage_data_source.dart';
import 'package:bb_mobile/_core/data/models/swap_model.dart';
import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/swap.dart';
import 'package:bb_mobile/_core/domain/repositories/swap_repository.dart';
import 'package:boltz/boltz.dart' as boltz_types;
// TODO: fallback to script path spend if coop fails

class BoltzSwapRepositoryImpl implements SwapRepository {
  final BoltzLibraryDataSource _boltzLib;
  final BoltzStorageDataSource _boltzStore;

  BoltzSwapRepositoryImpl({
    required BoltzLibraryDataSource boltzLib,
    required BoltzStorageDataSource boltzStore,
  })  : _boltzLib = boltzLib,
        _boltzStore = boltzStore;

  /// SWAP STREAM PROVIDER
  @override
  Stream<boltz_types.SwapStreamStatus> get stream => _boltzLib.stream;

  /// RECEIVE LN TO BTC
  @override
  Future<Swap> createLightningToBitcoinSwap({
    required String mnemonic,
    required String walletId,
    required int amountSat,
    required String electrumUrl,
    Environment environment = Environment.mainnet,
    required LightningSwapFees fees,
  }) async {
    final index = await _nextRevKeyIndex(walletId);
    final btcLnSwap = await _boltzLib.createBtcReverseSwap(
      mnemonic,
      index,
      amountSat,
      environment,
      electrumUrl,
    );
    await _boltzStore.storeBtcLnSwap(btcLnSwap);
    final swap = Swap(
      id: btcLnSwap.id,
      type: SwapType.lightningToBitcoin,
      status: SwapStatus.pending,
      environment: environment,
      creationTime: DateTime.now(),
      keyIndex: index,
      receiveSwapDetails: LnReceiveSwapDetails(
        receiveWalletId: walletId,
        invoice: btcLnSwap.invoice,
      ),
    );
    await _boltzStore.store(SwapModel.fromEntity(swap));
    // add to stream?
    return swap;
  }

  @override
  Future<String> claimLightningToBitcoinSwap({
    required String bitcoinAddress,
    required String swapId,
    required NetworkFees networkFees,
  }) async {
    final btcLnSwap = await _boltzStore.getBtcLnSwap(swapId);
    final signedTxHex = await _boltzLib.claimBtcReverseSwap(
      btcLnSwap,
      bitcoinAddress,
      networkFees,
      true,
    );
    final txid = await _boltzLib.broadcastBtcLnSwap(
      btcLnSwap,
      signedTxHex,
      false,
    );
    await _updateClaimedReceiveSwap(
      swapId: swapId,
      receiveAddress: bitcoinAddress,
      txid: txid,
    );
    return txid;
  }

  /// RECEIVE LN TO LBTC
  @override
  Future<Swap> createLightningToLiquidSwap({
    required String mnemonic,
    required String walletId,
    required int amountSat,
    required String electrumUrl,
    Environment environment = Environment.mainnet,
    required LightningSwapFees fees,
  }) async {
    final index = await _nextRevKeyIndex(walletId);
    final lbtcLnSwap = await _boltzLib.createLBtcReverseSwap(
      mnemonic,
      index,
      amountSat,
      environment,
      electrumUrl,
    );
    await _boltzStore.storeLbtcLnSwap(lbtcLnSwap);

    final swap = Swap(
      id: lbtcLnSwap.id,
      type: SwapType.lightningToLiquid,
      status: SwapStatus.pending,
      environment: environment,
      creationTime: DateTime.now(),
      keyIndex: index,
      receiveSwapDetails: LnReceiveSwapDetails(
        receiveWalletId: walletId,
        invoice: lbtcLnSwap.invoice,
      ),
    );
    await _boltzStore.store(SwapModel.fromEntity(swap));
    return swap;
  }

  @override
  Future<String> claimLightningToLiquidSwap({
    required String swapId,
    required String liquidAddress,
    required NetworkFees networkFees,
  }) async {
    final lbtcLnSwap = await _boltzStore.getLbtcLnSwap(swapId);
    final signedTxHex = await _boltzLib.claimLBtcReverseSwap(
      lbtcLnSwap,
      liquidAddress,
      networkFees,
      true,
    );
    final txid = await _boltzLib.broadcastLbtcLnSwap(
      lbtcLnSwap,
      signedTxHex,
      false,
    );
    await _updateClaimedReceiveSwap(
      swapId: lbtcLnSwap.id,
      receiveAddress: liquidAddress,
      txid: txid,
    );
    return txid;
  }

  /// SEND BTC TO LN
  @override
  Future<Swap> createBitcoinToLightningSwap({
    required String mnemonic,
    required String walletId,
    required String invoice,
    required String electrumUrl,
    Environment environment = Environment.mainnet,
    required LightningSwapFees fees,
  }) async {
    final index = await _nextSubKeyIndex(walletId);
    final btcLnSwap = await _boltzLib.createBtcSubmarineSwap(
      mnemonic,
      index,
      invoice,
      environment,
      electrumUrl,
    );
    await _boltzStore.storeBtcLnSwap(btcLnSwap);
    final swap = Swap(
      id: btcLnSwap.id,
      type: SwapType.bitcoinToLightning,
      status: SwapStatus.pending,
      environment: environment,
      creationTime: DateTime.now(),
      keyIndex: index,
      sendSwapDetails: LnSendSwapDetails(
        sendWalletId: walletId,
        invoice: invoice,
      ),
    );
    await _boltzStore.store(SwapModel.fromEntity(swap));
    return swap;
  }

  @override
  Future<void> coopSignBitcoinToLightningSwap({
    required String swapId,
  }) async {
    final btcLnSwap = await _boltzStore.getBtcLnSwap(swapId);

    await _boltzLib.coopSignBtcSubmarineSwap(
      btcLnSwap,
    );
    await _updateCompletedSendSwap(
      swapId: swapId,
    );
    return;
  }

  @override
  Future<String> refundBitcoinToLightningSwap({
    required String swapId,
    required String bitcoinAddress,
    required NetworkFees networkFees,
  }) async {
    final btcLnSwap = await _boltzStore.getBtcLnSwap(swapId);

    final signedTxHex = await _boltzLib.refundBtcSubmarineSwap(
      btcLnSwap,
      bitcoinAddress,
      networkFees,
      true,
    );
    // TODO: if coop fails attempt script path spend
    final txid = await _boltzLib.broadcastBtcLnSwap(
      btcLnSwap,
      signedTxHex,
      false,
    );
    await _updateRefundedSendSwap(
      swapId: swapId,
      refundAddress: bitcoinAddress,
      txid: txid,
    );

    return txid;
  }

  /// SEND LBTC TO LN
  @override
  Future<Swap> createLiquidToLightningSwap({
    required String mnemonic,
    required String walletId,
    required String invoice,
    required String electrumUrl,
    Environment environment = Environment.mainnet,
    required LightningSwapFees fees,
  }) async {
    final index = await _nextSubKeyIndex(walletId);
    final lbtcLnSwap = await _boltzLib.createLbtcSubmarineSwap(
      mnemonic,
      index,
      invoice,
      environment,
      electrumUrl,
    );
    await _boltzStore.storeLbtcLnSwap(lbtcLnSwap);
    final swap = Swap(
      id: lbtcLnSwap.id,
      type: SwapType.liquidToLightning,
      status: SwapStatus.pending,
      environment: environment,
      creationTime: DateTime.now(),
      keyIndex: index,
      sendSwapDetails: LnSendSwapDetails(
        sendWalletId: walletId,
        invoice: invoice,
      ),
    );
    await _boltzStore.store(SwapModel.fromEntity(swap));
    return swap;
  }

  @override
  Future<void> coopSignLiquidToLightningSwap({
    required String swapId,
  }) async {
    final lbtcLnSwap = await _boltzStore.getLbtcLnSwap(swapId);

    await _boltzLib.coopSignLbtcSubmarineSwap(
      lbtcLnSwap,
    );
    await _updateCompletedSendSwap(
      swapId: swapId,
    );
    return;
  }

  @override
  Future<String> refundLiquidToLightningSwap({
    required String swapId,
    required String liquidAddress,
    required NetworkFees networkFees,
  }) async {
    final lbtcLnSwap = await _boltzStore.getLbtcLnSwap(swapId);

    final signedTxHex = await _boltzLib.refundLbtcSubmarineSwap(
      lbtcLnSwap,
      liquidAddress,
      networkFees,
      true,
    );
    // TODO: if coop fails attempt script path spend
    final txid = await _boltzLib.broadcastLbtcLnSwap(
      lbtcLnSwap,
      signedTxHex,
      false,
    );
    await _updateRefundedSendSwap(
      swapId: swapId,
      refundAddress: liquidAddress,
      txid: txid,
    );

    return txid;
  }

  @override
  Future<Swap> createBitcoinToLiquidSwap({
    required String mnemonic,
    required String sendWalletId,
    required int amountSat,
    required Environment environment,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
    String? receiveWalletId,
    String? receipientAddress,
    required ChainSwapFees fees,
  } // if toSelf is true
      ) async {
    final index = await _nextChainKeyIndex(sendWalletId);
    final chainSwap = await _boltzLib.createBtcToLbtcChainSwap(
      mnemonic,
      index,
      amountSat,
      environment,
      btcElectrumUrl,
      lbtcElectrumUrl,
    );
    await _boltzStore.storeChainSwap(chainSwap);
    final swap = Swap(
      id: chainSwap.id,
      type: SwapType.bitcoinToLiquid,
      status: SwapStatus.pending,
      environment: environment,
      creationTime: DateTime.now(),
      keyIndex: index,
      chainSwapDetails: ChainSwapDetails(
        sendWalletId: sendWalletId,
        receiveWalletId: receiveWalletId,
        receiveAddress: receipientAddress,
      ),
    );
    await _boltzStore.store(SwapModel.fromEntity(swap));
    return swap;
  }

  @override
  Future<Swap> createLiquidToBitcoinSwap({
    required String mnemonic,
    required String sendWalletId,
    required int amountSat,
    required Environment environment,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
    String? receiveWalletId,
    String? receipientAddress,
    required ChainSwapFees fees,
  }) async {
    final index = await _nextChainKeyIndex(sendWalletId);
    final chainSwap = await _boltzLib.createLbtcToBtcChainSwap(
      mnemonic,
      index,
      amountSat,
      environment,
      btcElectrumUrl,
      lbtcElectrumUrl,
    );
    await _boltzStore.storeChainSwap(chainSwap);
    final swap = Swap(
      id: chainSwap.id,
      type: SwapType.liquidToBitcoin,
      status: SwapStatus.pending,
      environment: environment,
      creationTime: DateTime.now(),
      keyIndex: index,
      chainSwapDetails: ChainSwapDetails(
        sendWalletId: sendWalletId,
        receiveWalletId: receiveWalletId,
        receiveAddress: receipientAddress,
      ),
    );
    await _boltzStore.store(SwapModel.fromEntity(swap));
    return swap;
  }

  @override
  Future<String> claimLiquidToBitcoinSwap({
    required String bitcoinClaimAddress,
    required String swapId,
    required String liquidRefundAddress,
    required NetworkFees networkFees,
  }) async {
    final chainSwap = await _boltzStore.getChainSwap(swapId);
    final signedTxHex = await _boltzLib.claimLbtcToBtcChainSwap(
      chainSwap,
      bitcoinClaimAddress,
      liquidRefundAddress,
      networkFees,
      true,
    );
    final txid = await _boltzLib.broadcastChainSwapClaim(
      chainSwap,
      signedTxHex,
      false,
    );
    await _updateClaimedChainSwap(
      swapId: chainSwap.id,
      receiveAddress: bitcoinClaimAddress,
      txid: txid,
    );
    return txid;
  }

  @override
  Future<String> claimBitcoinToLiquidSwap({
    required String bitcoinRefundAddress,
    required String swapId,
    required String liquidClaimAddress,
    required NetworkFees networkFees,
  }) async {
    final chainSwap = await _boltzStore.getChainSwap(swapId);

    final signedTxHex = await _boltzLib.claimBtcToLbtcChainSwap(
      chainSwap,
      liquidClaimAddress,
      bitcoinRefundAddress,
      networkFees,
      true,
    );
    final txid = await _boltzLib.broadcastChainSwapClaim(
      chainSwap,
      signedTxHex,
      false,
    );
    await _updateClaimedChainSwap(
      swapId: swapId,
      receiveAddress: liquidClaimAddress,
      txid: txid,
    );
    return txid;
  }

  @override
  Future<String> refundBitcoinToLiquidSwap({
    required String bitcoinRefundAddress,
    required String swapId,
    required NetworkFees networkFees,
  }) async {
    final chainSwap = await _boltzStore.getChainSwap(swapId);

    final signedTxHex = await _boltzLib.refundBtcToLbtcChainSwap(
      chainSwap,
      bitcoinRefundAddress,
      networkFees,
      true,
    );
    // TODO: if coop fails attempt script path spend
    final txid = await _boltzLib.broadcastChainSwapRefund(
      chainSwap,
      signedTxHex,
      false,
    );
    await _updateRefundedSendSwap(
      swapId: swapId,
      refundAddress: bitcoinRefundAddress,
      txid: txid,
    );
    return txid;
  }

  @override
  Future<String> refundLiquidToBitcoinSwap({
    required String swapId,
    required String liquidRefundAddress,
    required NetworkFees networkFees,
  }) async {
    final chainSwap = await _boltzStore.getChainSwap(swapId);

    final signedTxHex = await _boltzLib.refundLbtcToBtcChainSwap(
      chainSwap,
      liquidRefundAddress,
      networkFees,
      true,
    );
    // TODO: if coop fails attempt script path spend
    final txid = await _boltzLib.broadcastChainSwapRefund(
      chainSwap,
      signedTxHex,
      false,
    );
    await _updateRefundedSendSwap(
      swapId: chainSwap.id,
      refundAddress: liquidRefundAddress,
      txid: txid,
    );
    return txid;
  }

  // STORAGE
  @override
  Future<Swap> getSwap({required String swapId}) async {
    // TODO: implement getSwapById
    final swapModel = await _boltzStore.get(swapId);
    if (swapModel == null) {
      throw "No swap found";
    }
    return swapModel.toEntity();
  }

  @override
  Future<(Swap, NextSwapAction)> getBtcLnSwapAndAction({
    required String swapId,
    required String status,
  }) async {
    final btcLnSwap = await _boltzStore.getBtcLnSwap(swapId);
    final action = await _boltzLib.getBtcLnSwapAction(btcLnSwap, status);
    final swap = await _boltzStore.get(swapId);
    if (swap == null) {
      throw "No swap found";
    }
    return (swap.toEntity(), action);
  }

  @override
  Future<(Swap, NextSwapAction)> getLbtcLnSwapAndAction({
    required String swapId,
    required String status,
  }) async {
    final lbtcLnSwap = await _boltzStore.getLbtcLnSwap(swapId);
    final action = await _boltzLib.getLbtcLnSwapAction(lbtcLnSwap, status);
    final swap = await _boltzStore.get(swapId);
    if (swap == null) {
      throw "No swap found";
    }
    return (swap.toEntity(), action);
  }

  @override
  Future<(Swap, NextSwapAction)> getChainSwapAndAction({
    required String swapId,
    required String status,
  }) async {
    final chainSwap = await _boltzStore.getChainSwap(swapId);
    final action = await _boltzLib.getChainSwapAction(chainSwap, status);
    final swap = await _boltzStore.get(swapId);
    if (swap == null) {
      throw "No swap found";
    }
    return (swap.toEntity(), action);
  }

  /// STORAGE
  @override
  Future<void> updatePaidSendSwap({
    required String swapId,
    required String txid,
  }) async {
    final swapModel = await _boltzStore.get(swapId);
    if (swapModel == null) {
      throw "No swap model found";
    }

    final swap = swapModel.toEntity();
    if (swap.status != SwapStatus.pending) {
      throw "Can only update status of a pending swap";
    }

    final sendSwapDetails = swap.sendSwapDetails!.copyWith(
      sendTxid: txid,
    );
    final updatedSwap = swap.copyWith(
      sendSwapDetails: sendSwapDetails,
      status: SwapStatus.paid,
    );
    await _boltzStore.store(SwapModel.fromEntity(updatedSwap));
  }

  @override
  Future<void> updateExpiredSwap({
    required String swapId,
  }) async {
    final swapModel = await _boltzStore.get(swapId);
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
    await _boltzStore.store(SwapModel.fromEntity(updatedSwap));
  }

  @override
  Future<void> updateFailedSwap({
    required String swapId,
  }) async {
    final swapModel = await _boltzStore.get(swapId);
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
    await _boltzStore.store(SwapModel.fromEntity(updatedSwap));
  }

  /// PRIVATE
  Future<void> _updateClaimedReceiveSwap({
    required String swapId,
    required String receiveAddress,
    required String txid,
  }) async {
    final swapModel = await _boltzStore.get(swapId);
    if (swapModel == null) {
      throw "No swap model found";
    }

    final swap = swapModel.toEntity();
    if (swap.status != SwapStatus.pending) {
      throw "Can only update status of a pending swap";
    }
    final receiveSwapDetails = swap.receiveSwapDetails!.copyWith(
      receiveAddress: receiveAddress,
      receiveTxid: txid,
    );
    final updatedSwap = swap.copyWith(
      receiveSwapDetails: receiveSwapDetails,
      completionTime: DateTime.now(),
      status: SwapStatus.completed,
    );
    await _boltzStore.store(SwapModel.fromEntity(updatedSwap));
  }

  Future<void> _updateClaimedChainSwap({
    required String swapId,
    required String receiveAddress,
    required String txid,
  }) async {
    final swapModel = await _boltzStore.get(swapId);
    if (swapModel == null) {
      throw "No swap model found";
    }

    final swap = swapModel.toEntity();
    if (swap.status != SwapStatus.paid) {
      throw "Can only update status of a paid swap";
    }
    final chainSwapDetails = swap.chainSwapDetails!.copyWith(
      receiveAddress: receiveAddress,
      receiveTxid: txid,
    );
    final updatedSwap = swap.copyWith(
      chainSwapDetails: chainSwapDetails,
      completionTime: DateTime.now(),
      status: SwapStatus.completed,
    );
    await _boltzStore.store(SwapModel.fromEntity(updatedSwap));
  }

  Future<void> _updateRefundedSendSwap({
    required String swapId,
    required String refundAddress,
    required String txid,
  }) async {
    final swapModel = await _boltzStore.get(swapId);
    if (swapModel == null) {
      throw "No swap model found";
    }

    final swap = swapModel.toEntity();
    if (swap.status != SwapStatus.paid) {
      throw "Can only update status of a paid swap";
    }
    final sendSwapDetails = swap.sendSwapDetails!.copyWith(
      refundAddress: refundAddress,
      refundTxid: txid,
    );
    final updatedSwap = swap.copyWith(
      sendSwapDetails: sendSwapDetails,
      completionTime: DateTime.now(),
      status: SwapStatus.refunded,
    );
    await _boltzStore.store(SwapModel.fromEntity(updatedSwap));
  }

  Future<void> _updateCompletedSendSwap({
    required String swapId,
  }) async {
    final swapModel = await _boltzStore.get(swapId);
    if (swapModel == null) {
      throw "No swap model found";
    }

    final swap = swapModel.toEntity();
    if (swap.status != SwapStatus.paid) {
      throw "Can only update status of a paid swap";
    }

    final updatedSwap = swap.copyWith(
      completionTime: DateTime.now(),
      status: SwapStatus.completed,
    );
    await _boltzStore.store(SwapModel.fromEntity(updatedSwap));
  }

  // TODO: next key index is specific for each swap type
  // each swap uses a different account' path
  // we should have nextReverseIndex, nextSubmarineIndex, nextChainIndex
  Future<int> _nextRevKeyIndex(String walletId) async {
    final swaps = await _getRevSwapsForWallet(walletId);
    final nextWalletIndex =
        swaps.isEmpty ? 0 : swaps.map((swap) => swap.keyIndex).reduce(max) + 1;
    return nextWalletIndex;
  }

  Future<List<Swap>> _getRevSwapsForWallet(String walletId) async {
    return (await _boltzStore.getAll())
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
    return (await _boltzStore.getAll())
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
    return (await _boltzStore.getAll())
        .map((swapModel) => swapModel.toEntity())
        .where(
          (swap) =>
              swap.type == SwapType.bitcoinToLiquid ||
              swap.type == SwapType.liquidToBitcoin,
        )
        .toList();
  }

  Future<List<Swap>> _getSwapsForWallet(String walletId) async {
    return (await _boltzStore.getAll())
        .map((swapModel) => swapModel.toEntity())
        .where((swap) => _swapBelongsToWallet(swap, walletId))
        .toList();
  }

  bool _swapBelongsToWallet(Swap swap, String walletId) {
    final chain = swap.chainSwapDetails;
    if (chain?.sendWalletId == walletId || chain?.receiveWalletId == walletId) {
      return true;
    }
    final lnReceive = swap.receiveSwapDetails;
    if (lnReceive?.receiveWalletId == walletId) {
      return true;
    }
    final lnSend = swap.sendSwapDetails;
    if (lnSend?.sendWalletId == walletId) {
      return true;
    }
    return false;
  }

  @override
  Future<void> updateSwap({required Swap swap}) async {
    return _boltzStore.store(SwapModel.fromEntity(swap));
  }

  @override
  void addSwapToStream({required String swapId}) {
    _boltzLib.subscribeToSwaps([swapId]);
  }

  @override
  void removeSwapFromStream({required String swapId}) {
    _boltzLib.unsubscribeToSwaps([swapId]);
  }

  @override
  void reinitializeStreamWithSwaps({required List<String> swapIds}) {
    _boltzLib.resetStream();
    _boltzLib.subscribeToSwaps(swapIds);
  }

  @override
  Future<List<Swap>> getOngoingSwaps() async {
    final allSwapModels = await _boltzStore.getAll();
    final allSwaps =
        allSwapModels.map((swapModel) => swapModel.toEntity()).toList();
    return allSwaps
        .where((swap) =>
            swap.status == SwapStatus.pending || swap.status == SwapStatus.paid)
        .toList();
  }

  @override
  Future<ChainSwapFeesAndLimits> getChainSwapFeesAndLimits() async {
    final fees = await _boltzLib.getChainFeesAndLimits();
    return fees.toDomainEntity();
  }

  @override
  Future<ReverseSwapFeesAndLimits> getReverseSwapFeesAndLimits() async {
    final fees = await _boltzLib.getReverseFeesAndLimits();
    return fees.toDomainEntity();
  }

  @override
  Future<SubmarineSwapFeesAndLimits> getSubmarineSwapFeesAndLimits() async {
    final fees = await _boltzLib.getSubmarineFeesAndLimits();
    return fees.toDomainEntity();
  }
}

extension ConvertReverseFeesAndLimits on boltz_types.ReverseFeesAndLimits {
  ReverseSwapFeesAndLimits toDomainEntity() {
    return ReverseSwapFeesAndLimits(
      bitcoinLimits: SwapLimits(
        min: btcLimits.minimal.toInt(),
        max: btcLimits.maximal.toInt(),
      ),
      liquidLimits: SwapLimits(
        min: lbtcLimits.minimal.toInt(),
        max: lbtcLimits.maximal.toInt(),
      ),
      bitcoinFees: LightningSwapFees(
        percentage: btcFees.percentage,
        minerFees: btcFees.minerFees.lockup.toInt(),
      ),
      liquidFees: LightningSwapFees(
        percentage: lbtcFees.percentage,
        minerFees: lbtcFees.minerFees.lockup.toInt(),
      ),
    );
  }
}

extension ConvertSubmarineFeesAndLimits on boltz_types.SubmarineFeesAndLimits {
  SubmarineSwapFeesAndLimits toDomainEntity() {
    return SubmarineSwapFeesAndLimits(
      bitcoinLimits: SwapLimits(
        min: btcLimits.minimal.toInt(),
        max: btcLimits.maximal.toInt(),
      ),
      liquidLimits: SwapLimits(
        min: lbtcLimits.minimal.toInt(),
        max: lbtcLimits.maximal.toInt(),
      ),
      bitcoinFees: LightningSwapFees(
        percentage: btcFees.percentage,
        minerFees: btcFees.minerFees.toInt(),
      ),
      liquidFees: LightningSwapFees(
        percentage: lbtcFees.percentage,
        minerFees: lbtcFees.minerFees.toInt(),
      ),
    );
  }
}

extension ConvertChainFeesAndLimits on boltz_types.ChainFeesAndLimits {
  ChainSwapFeesAndLimits toDomainEntity() {
    return ChainSwapFeesAndLimits(
      bitcoinLimits: SwapLimits(
        min: btcLimits.minimal.toInt(),
        max: btcLimits.maximal.toInt(),
      ),
      liquidLimits: SwapLimits(
        min: lbtcLimits.minimal.toInt(),
        max: lbtcLimits.maximal.toInt(),
      ),
      bitcoinFees: ChainSwapFees(
        percentage: btcFees.percentage,
        minerFees: ChainMinerFees(
          lockup: btcFees.userLockup.toInt(),
          claim: btcFees.userClaim.toInt(),
        ),
      ),
      liquidFees: ChainSwapFees(
        percentage: lbtcFees.percentage,
        minerFees: ChainMinerFees(
          lockup: lbtcFees.userLockup.toInt(),
          claim: lbtcFees.userClaim.toInt(),
        ),
      ),
    );
  }
}
