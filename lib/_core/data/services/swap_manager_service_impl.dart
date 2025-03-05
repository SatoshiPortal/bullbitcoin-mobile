import 'package:bb_mobile/_core/data/repositories/boltz_swap_repository_impl.dart';
import 'package:bb_mobile/_core/domain/entities/swap.dart';
import 'package:bb_mobile/_core/domain/services/swap_manager_service.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';

class SwapManagerServiceImpl implements SwapManagerService {
  final WalletManagerService _walletManager;
  final BoltzSwapRepositoryImpl _boltzRepo;

  SwapManagerServiceImpl({
    required WalletManagerService walletManager,
    required BoltzSwapRepositoryImpl boltzRepo,
  })  : _walletManager = walletManager,
        _boltzRepo = boltzRepo {
    _boltzRepo.stream.listen((event) async {
      await processSwap(swapId: event.id, status: event.status.toString());
    });
  }

  Future<void> processSwap({
    required String swapId,
    required String status,
  }) async {
    print("Processing swap $swapId with status $status");

    final swap = await _boltzRepo.getSwap(swapId: swapId);

    switch (swap.type) {
      case SwapType.lightningToBitcoin:
      case SwapType.bitcoinToLightning:
        final (swap, action) = await _boltzRepo.getBtcLnSwapAndAction(
          swapId: swapId,
          status: status,
        );
        switch (action) {
          case NextSwapAction.wait:
            return;
          case NextSwapAction.claim:
            await _processReceiveBtcClaim(swap: swap);
          case NextSwapAction.coopSign:
            await _processSendBtcCoopSign(swap: swap);
          case NextSwapAction.refund:
            await _processSendBtcRefund(swap: swap);
          case NextSwapAction.close:
          // TODO: Close swap repository method
          // TODO: Stop listening to swap ID in stream
        }
      case SwapType.lightningToLiquid:
      case SwapType.liquidToLightning:
        final (swap, action) = await _boltzRepo.getLbtcLnSwapAndAction(
          swapId: swapId,
          status: status,
        );
        switch (action) {
          case NextSwapAction.wait:
            return;
          case NextSwapAction.claim:
            await _processReceiveLBtcClaim(swap: swap);
          case NextSwapAction.coopSign:
            await _processSendLbtcCoopSign(swap: swap);
          case NextSwapAction.refund:
            await _processSendLbtcRefund(swap: swap);
          case NextSwapAction.close:
          // TODO: Close swap repository method
          // TODO: Stop listening to swap ID in stream
        }
      case SwapType.liquidToBitcoin:
        final (swap, action) = await _boltzRepo.getChainSwapAndAction(
          swapId: swapId,
          status: status,
        );
        switch (action) {
          case NextSwapAction.wait:
            return;
          case NextSwapAction.claim:
            await _processChainBtcClaim(swap: swap);
          case NextSwapAction.coopSign:
            return;
          case NextSwapAction.refund:
            await _processChainLbtcRefund(swap: swap);
          case NextSwapAction.close:
          // TODO: Close swap repository method
          // TODO: Stop listening to swap ID in stream
        }
      case SwapType.bitcoinToLiquid:
        final (swap, action) = await _boltzRepo.getChainSwapAndAction(
          swapId: swapId,
          status: status,
        );
        switch (action) {
          case NextSwapAction.wait:
            return;
          case NextSwapAction.claim:
            await _processChainLbtcClaim(swap: swap);
          case NextSwapAction.coopSign:
            return;
          case NextSwapAction.refund:
            await _processChainBtcRefund(swap: swap);
          // TODO: add label to txid
          case NextSwapAction.close:
          // TODO: Close swap repository method
          // TODO: Stop listening to swap ID in stream
        }
    }
    return;
  }

  Future<void> _processReceiveBtcClaim({
    required Swap swap,
  }) async {
    if (swap.receiveSwapDetails == null) {
      throw Exception('Swap does not have receive details');
    }
    // TODO: validate and add label to bitcoin address
    final address = await _walletManager.getNewAddress(
        walletId: swap.receiveSwapDetails!.receiveWalletId);
    // TODO: get network fees
    const networkFees = NetworkFees.relative(3.0);
    final claimTxId = await _boltzRepo.claimLightningToBitcoinSwap(
      swapId: swap.id,
      networkFees: networkFees,
      tryCooperate: true,
      broadcastViaBoltz: false,
      bitcoinAddress: address.address,
    );
    // TODO: add label to txid
  }

  Future<void> _processSendBtcRefund({
    required Swap swap,
  }) async {
    if (swap.sendSwapDetails == null) {
      throw Exception('Swap does not have send details');
    }
    final address = await _walletManager.getNewAddress(
        walletId: swap.sendSwapDetails!.sendWalletId);
    // TODO: validate and add label to bitcoin address
    const networkFees = NetworkFees.relative(3.0);
    final refundTxid = await _boltzRepo.refundBitcoinToLightningSwap(
      swapId: swap.id,
      bitcoinAddress: address.address,
      networkFees: networkFees,
      tryCooperate: true,
      broadcastViaBoltz: false,
    );
    // TODO: add label to txid
  }

  Future<void> _processReceiveLBtcClaim({
    required Swap swap,
  }) async {
    if (swap.receiveSwapDetails == null) {
      throw Exception('Swap does not have receive details');
    }
    final address = await _walletManager.getNewAddress(
      walletId: swap.receiveSwapDetails!.receiveWalletId,
    );
    // TODO: validate and add label to liquid address
    const networkFees = NetworkFees.relative(3.0);
    final claimTxId = await _boltzRepo.claimLightningToLiquidSwap(
      swapId: swap.id,
      networkFees: networkFees,
      tryCooperate: true,
      broadcastViaBoltz: false,
      liquidAddress: address.address,
    );
    // TODO: add label to txid
  }

  Future<void> _processSendLbtcRefund({
    required Swap swap,
  }) async {
    if (swap.sendSwapDetails == null) {
      throw Exception('Swap does not have send details');
    }
    final address = await _walletManager.getNewAddress(
      walletId: swap.sendSwapDetails!.sendWalletId,
    );
    // TODO: validate and add label to liquid address
    const networkFees = NetworkFees.relative(3.0);
    final refundTxid = await _boltzRepo.refundLiquidToLightningSwap(
      swapId: swap.id,
      liquidAddress: address.address,
      networkFees: networkFees,
      tryCooperate: true,
      broadcastViaBoltz: false,
    );
    // TODO: add label to txid
  }

  Future<void> _processSendBtcCoopSign({
    required Swap swap,
  }) async {
    if (swap.sendSwapDetails == null) {
      throw Exception('Swap does not have send details');
    }
    await _boltzRepo.coopSignBitcoinToLightningSwap(
      swapId: swap.id,
    );
  }

  Future<void> _processSendLbtcCoopSign({
    required Swap swap,
  }) async {
    if (swap.sendSwapDetails == null) {
      throw Exception('Swap does not have send details');
    }
    await _boltzRepo.coopSignLiquidToLightningSwap(
      swapId: swap.id,
    );
  }

  Future<void> _processChainBtcClaim({
    required Swap swap,
  }) async {
    if (swap.chainSwapDetails == null) {
      throw Exception('Swap does not have chain details');
    }
    final claimAddress = await _walletManager.getNewAddress(
      walletId: swap.chainSwapDetails!.receiveWalletId!,
    );
    final refundAddress = await _walletManager.getNewAddress(
      walletId: swap.chainSwapDetails!.sendWalletId,
    );
    // TODO: add label to bitcoin claim address
    const networkFees = NetworkFees.relative(3.0);
    final claimTxId = await _boltzRepo.claimLiquidToBitcoinSwap(
      swapId: swap.id,
      networkFees: networkFees,
      tryCooperate: true,
      broadcastViaBoltz: false,
      bitcoinClaimAddress: claimAddress.address,
      liquidRefundAddress: refundAddress.address,
    );
    // TODO: add label to txid
  }

  Future<void> _processChainBtcRefund({
    required Swap swap,
  }) async {
    if (swap.chainSwapDetails == null) {
      throw Exception('Swap does not have chain details');
    }
    final refundAddress = await _walletManager.getNewAddress(
      walletId: swap.chainSwapDetails!.sendWalletId,
    );
    // TODO: add label to bitcoin refund address
    const networkFees = NetworkFees.relative(3.0);
    await _boltzRepo.refundBitcoinToLiquidSwap(
      swapId: swap.id,
      networkFees: networkFees,
      tryCooperate: true,
      broadcastViaBoltz: false,
      bitcoinRefundAddress: refundAddress.address,
    );
    // TODO: add label to txid
  }

  Future<void> _processChainLbtcClaim({
    required Swap swap,
  }) async {
    if (swap.chainSwapDetails == null) {
      throw Exception('Swap does not have chain details');
    }
    final claimAddress = await _walletManager.getNewAddress(
      walletId: swap.chainSwapDetails!.receiveWalletId!,
    );
    final refundAddress = await _walletManager.getNewAddress(
      walletId: swap.chainSwapDetails!.sendWalletId,
    ); // TODO: add label to bitcoin claim address
    const networkFees = NetworkFees.relative(3.0);
    final claimTxId = await _boltzRepo.claimBitcoinToLiquidSwap(
      swapId: swap.id,
      networkFees: networkFees,
      tryCooperate: true,
      broadcastViaBoltz: false,
      liquidClaimAddress: claimAddress.address,
      bitcoinRefundAddress: refundAddress.address,
    );
    // TODO: add label to txid
  }

  Future<void> _processChainLbtcRefund({
    required Swap swap,
  }) async {
    if (swap.chainSwapDetails == null) {
      throw Exception('Swap does not have chain details');
    }
    final refundAddress = await _walletManager.getNewAddress(
      walletId: swap.chainSwapDetails!.sendWalletId,
    );
    // TODO: add label to liquid refund address
    const networkFees = NetworkFees.relative(3.0);
    await _boltzRepo.refundLiquidToBitcoinSwap(
      swapId: swap.id,
      networkFees: networkFees,
      tryCooperate: true,
      broadcastViaBoltz: false,
      liquidRefundAddress: refundAddress.address,
    );
    // TODO: add label to txid
  }
}
