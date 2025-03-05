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
  @override
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
            await _processReceiveLnToBitcoinClaim(swap: swap);
          case NextSwapAction.coopSign:
            await _processSendBitcoinToLnCoopSign(swap: swap);
          case NextSwapAction.refund:
            await _processSendBitcoinToLnRefund(swap: swap);
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
            await _processReceiveLnToLiquidClaim(swap: swap);
          case NextSwapAction.coopSign:
            await _processSendLiquidToLnCoopSign(swap: swap);
          case NextSwapAction.refund:
            await _processSendLiquidToLnRefund(swap: swap);
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
            await _processChainLiquidToBitcoinClaim(swap: swap);
          case NextSwapAction.coopSign:
            return;
          case NextSwapAction.refund:
            await _processChainLiquidToBitcoinRefund(swap: swap);
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
            await _processChainBitcoinToLiquidClaim(swap: swap);
          case NextSwapAction.coopSign:
            return;
          case NextSwapAction.refund:
            await _processChainBitcoinToLiquidRefund(swap: swap);
          // TODO: add label to txid
          case NextSwapAction.close:
          // TODO: Close swap repository method
          // TODO: Stop listening to swap ID in stream
        }
    }
    return;
  }

  Future<void> _processReceiveLnToBitcoinClaim({
    required Swap swap,
  }) async {
    if (swap.receiveSwapDetails == null) {
      throw Exception('Swap does not have receive details');
    }
    final address = await _walletManager.getNewAddress(
      walletId: swap.receiveSwapDetails!.receiveWalletId,
    );
    if (!address.isBitcoin) {
      throw Exception('Claim Address is not a Bitcoin address');
    }
    // TODO: add label to bitcoin address

    const networkFees = NetworkFees.relative(3.0);
    final claimTxId = await _boltzRepo.claimLightningToBitcoinSwap(
      swapId: swap.id,
      networkFees: networkFees,
      bitcoinAddress: address.address,
    );
    // TODO: add label to txid
  }

  Future<void> _processSendBitcoinToLnRefund({
    required Swap swap,
  }) async {
    if (swap.sendSwapDetails == null) {
      throw Exception('Swap does not have send details');
    }
    final address = await _walletManager.getNewAddress(
      walletId: swap.sendSwapDetails!.sendWalletId,
    );
    if (!address.isBitcoin) {
      throw Exception('Refund Address is not a Bitcoin address');
    }
    // TODO: add label to bitcoin address
    const networkFees = NetworkFees.relative(3.0);
    final refundTxid = await _boltzRepo.refundBitcoinToLightningSwap(
      swapId: swap.id,
      bitcoinAddress: address.address,
      networkFees: networkFees,
    );
    // TODO: add label to txid
  }

  Future<void> _processReceiveLnToLiquidClaim({
    required Swap swap,
  }) async {
    if (swap.receiveSwapDetails == null) {
      throw Exception('Swap does not have receive details');
    }
    final address = await _walletManager.getNewAddress(
      walletId: swap.receiveSwapDetails!.receiveWalletId,
    );
    if (!address.isLiquid) {
      throw Exception('Claim Address is not a Liquid address');
    }
    // TODO: add label to liquid address
    const networkFees = NetworkFees.relative(3.0);
    final claimTxId = await _boltzRepo.claimLightningToLiquidSwap(
      swapId: swap.id,
      networkFees: networkFees,
      liquidAddress: address.address,
    );
    // TODO: add label to txid
  }

  Future<void> _processSendLiquidToLnRefund({
    required Swap swap,
  }) async {
    if (swap.sendSwapDetails == null) {
      throw Exception('Swap does not have send details');
    }
    final address = await _walletManager.getNewAddress(
      walletId: swap.sendSwapDetails!.sendWalletId,
    );
    if (!address.isLiquid) {
      throw Exception('Refund Address is not a Liquid address');
    }
    // TODO: add label to liquid address
    const networkFees = NetworkFees.relative(3.0);
    final refundTxid = await _boltzRepo.refundLiquidToLightningSwap(
      swapId: swap.id,
      liquidAddress: address.address,
      networkFees: networkFees,
    );
    // TODO: add label to txid
  }

  Future<void> _processSendBitcoinToLnCoopSign({
    required Swap swap,
  }) async {
    if (swap.sendSwapDetails == null) {
      throw Exception('Swap does not have send details');
    }
    await _boltzRepo.coopSignBitcoinToLightningSwap(
      swapId: swap.id,
    );
  }

  Future<void> _processSendLiquidToLnCoopSign({
    required Swap swap,
  }) async {
    if (swap.sendSwapDetails == null) {
      throw Exception('Swap does not have send details');
    }
    await _boltzRepo.coopSignLiquidToLightningSwap(
      swapId: swap.id,
    );
  }

  Future<void> _processChainLiquidToBitcoinClaim({
    required Swap swap,
  }) async {
    if (swap.chainSwapDetails == null) {
      throw Exception('Swap does not have chain details');
    }
    final claimAddress = await _walletManager.getNewAddress(
      walletId: swap.chainSwapDetails!.receiveWalletId!,
    );
    if (!claimAddress.isBitcoin) {
      throw Exception('Claim address is not a Bitcoin address');
    }
    final refundAddress = await _walletManager.getNewAddress(
      walletId: swap.chainSwapDetails!.sendWalletId,
    );
    if (!refundAddress.isLiquid) {
      throw Exception('Refund address is not a Liquid address');
    }
    // TODO: add label to bitcoin claim address
    const networkFees = NetworkFees.relative(3.0);
    final claimTxId = await _boltzRepo.claimLiquidToBitcoinSwap(
      swapId: swap.id,
      networkFees: networkFees,
      bitcoinClaimAddress: claimAddress.address,
      liquidRefundAddress: refundAddress.address,
    );
    // TODO: add label to txid
  }

  Future<void> _processChainBitcoinToLiquidRefund({
    required Swap swap,
  }) async {
    if (swap.chainSwapDetails == null) {
      throw Exception('Swap does not have chain details');
    }
    final refundAddress = await _walletManager.getNewAddress(
      walletId: swap.chainSwapDetails!.sendWalletId,
    );
    if (!refundAddress.isBitcoin) {
      throw Exception('Refund address is not a Bitcoin address');
    }
    // TODO: add label to bitcoin refund address
    const networkFees = NetworkFees.relative(3.0);
    await _boltzRepo.refundBitcoinToLiquidSwap(
      swapId: swap.id,
      networkFees: networkFees,
      bitcoinRefundAddress: refundAddress.address,
    );
    // TODO: add label to txid
  }

  Future<void> _processChainBitcoinToLiquidClaim({
    required Swap swap,
  }) async {
    if (swap.chainSwapDetails == null) {
      throw Exception('Swap does not have chain details');
    }
    final claimAddress = await _walletManager.getNewAddress(
      walletId: swap.chainSwapDetails!.receiveWalletId!,
    );
    if (!claimAddress.isLiquid) {
      throw Exception('Claim address is not a Liquid address');
    }
    final refundAddress = await _walletManager.getNewAddress(
      walletId: swap.chainSwapDetails!.sendWalletId,
    );
    if (!refundAddress.isBitcoin) {
      throw Exception('Refund address is not a Bitcoin address');
    }
    // TODO: add label to bitcoin claim address
    const networkFees = NetworkFees.relative(3.0);
    final claimTxId = await _boltzRepo.claimBitcoinToLiquidSwap(
      swapId: swap.id,
      networkFees: networkFees,
      liquidClaimAddress: claimAddress.address,
      bitcoinRefundAddress: refundAddress.address,
    );
    // TODO: add label to txid
  }

  Future<void> _processChainLiquidToBitcoinRefund({
    required Swap swap,
  }) async {
    if (swap.chainSwapDetails == null) {
      throw Exception('Swap does not have chain details');
    }
    final refundAddress = await _walletManager.getNewAddress(
      walletId: swap.chainSwapDetails!.sendWalletId,
    );
    if (!refundAddress.isLiquid) {
      throw Exception('Claim address is not a Liquid address');
    }
    // TODO: add label to liquid refund address
    const networkFees = NetworkFees.relative(3.0);
    await _boltzRepo.refundLiquidToBitcoinSwap(
      swapId: swap.id,
      networkFees: networkFees,
      liquidRefundAddress: refundAddress.address,
    );
    // TODO: add label to txid
  }
}
