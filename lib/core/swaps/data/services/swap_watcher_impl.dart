import 'dart:async';

import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository_impl.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/services/swap_watcher_service.dart';
import 'package:bb_mobile/core/wallet/domain/services/wallet_manager_service.dart';
import 'package:flutter/foundation.dart';

class SwapWatcherServiceImpl implements SwapWatcherService {
  final WalletManagerService _walletManager;
  final BoltzSwapRepositoryImpl _boltzRepo;

  final StreamController<Swap> _swapStreamController =
      StreamController<Swap>.broadcast();

  SwapWatcherServiceImpl({
    required WalletManagerService walletManager,
    required BoltzSwapRepositoryImpl boltzRepo,
  })  : _walletManager = walletManager,
        _boltzRepo = boltzRepo {
    startWatching();
  }

  @override
  Stream<Swap> get swapStream =>
      _swapStreamController.stream.asBroadcastStream();

  void startWatching() {
    _boltzRepo.swapUpdatesStream.listen(
      (swap) async {
        debugPrint(
          'SwapWatcher received swap update: ${swap.id}:${swap.status}',
        );
        // Notify the rest of the app about the swap update before processing it
        // which changes the status of the swap again
        _swapStreamController.add(swap);
        await _processSwap(swap);
      },
      onError: (error) {
        debugPrint('Swap stream error in watcher: $error');
      },
      onDone: () {
        debugPrint('Swap stream done in watcher.');
      },
      cancelOnError: false,
    );

    debugPrint('Swap watcher started and listening');
  }

  @override
  Future<void> restartWatcherWithOngoingSwaps() async {
    final swaps = await _boltzRepo.getOngoingSwaps();
    final swapIdsToWatch = swaps.map((swap) => swap.id).toList();
    _boltzRepo.reinitializeStreamWithSwaps(swapIds: swapIdsToWatch);
    startWatching();
  }

  Future<void> _processSwap(Swap swap) async {
    switch (swap.status) {
      case SwapStatus.claimable:
        switch (swap.type) {
          case SwapType.lightningToBitcoin:
            await _processReceiveLnToBitcoinClaim(swap: swap as LnReceiveSwap);
          case SwapType.lightningToLiquid:
            await _processReceiveLnToLiquidClaim(swap: swap as LnReceiveSwap);
          case SwapType.liquidToBitcoin:
            await _processChainLiquidToBitcoinClaim(swap: swap as ChainSwap);
          case SwapType.bitcoinToLiquid:
            await _processChainBitcoinToLiquidClaim(swap: swap as ChainSwap);
          default:
            return;
        }

      case SwapStatus.refundable:
        switch (swap.type) {
          case SwapType.bitcoinToLightning:
            await _processSendBitcoinToLnRefund(swap: swap as LnSendSwap);
          case SwapType.liquidToLightning:
            await _processSendLiquidToLnRefund(swap: swap as LnSendSwap);
          case SwapType.liquidToBitcoin:
            await _processChainLiquidToBitcoinRefund(swap: swap as ChainSwap);
          case SwapType.bitcoinToLiquid:
            await _processChainBitcoinToLiquidRefund(swap: swap as ChainSwap);
          default:
            return;
        }

      case SwapStatus.canCoop:
        switch (swap.type) {
          case SwapType.bitcoinToLightning:
            await _processSendBitcoinToLnCoopSign(swap: swap as LnSendSwap);
          case SwapType.liquidToLightning:
            await _processSendLiquidToLnCoopSign(swap: swap as LnSendSwap);
          default:
            return;
        }

      case SwapStatus.pending:
      case SwapStatus.paid:
      case SwapStatus.completed:
      case SwapStatus.expired:
      case SwapStatus.failed:
        // No processing needed for these statuses anymore
        return;
    }
  }

  Future<void> _processReceiveLnToBitcoinClaim({
    required LnReceiveSwap swap,
  }) async {
    final receiveAddress = swap.receiveAddress;
    if (receiveAddress == null) {
      throw Exception('Receive address is null');
    }
    final claimTxId = await _boltzRepo.claimLightningToBitcoinSwap(
      swapId: swap.id,
      absoluteFees: swap.claimFee!,
      bitcoinAddress: swap.receiveAddress!,
    );
    final updatedSwap = swap.copyWith(
      receiveTxid: claimTxId,
      receiveAddress: swap.receiveAddress,
      status: SwapStatus.completed,
    );
    // TODO: add label to txid
    await _boltzRepo.updateSwap(swap: updatedSwap);
  }

  Future<void> _processSendBitcoinToLnRefund({
    required LnSendSwap swap,
  }) async {
    final address = await _walletManager.getNewAddress(
      walletId: swap.sendWalletId,
    );
    if (!address.isBitcoin) {
      throw Exception('Refund Address is not a Bitcoin address');
    }
    // TODO: add label to bitcoin address
    await _boltzRepo.refundBitcoinToLightningSwap(
      swapId: swap.id,
      bitcoinAddress: address.address,
      absoluteFees: swap.claimFee!,
    );
    // TODO: add label to txid
  }

  Future<void> _processReceiveLnToLiquidClaim({
    required LnReceiveSwap swap,
  }) async {
    try {
      final receiveAddress = swap.receiveAddress;
      if (receiveAddress == null) {
        throw Exception('Receive address is null');
      }
      // TODO: add label to liquid address based on swap.invoice.description
      final claimTxId = await _boltzRepo.claimLightningToLiquidSwap(
        swapId: swap.id,
        absoluteFees: swap.claimFee!,
        liquidAddress: receiveAddress,
      );
      final updatedSwap = swap.copyWith(
        receiveTxid: claimTxId,
        receiveAddress: receiveAddress,
        status: SwapStatus.completed,
      );
      // TODO: add label to txid based on swap.invoice.description
      await _boltzRepo.updateSwap(swap: updatedSwap);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _processSendLiquidToLnRefund({
    required LnSendSwap swap,
  }) async {
    final address = await _walletManager.getNewAddress(
      walletId: swap.sendWalletId,
    );
    if (!address.isLiquid) {
      throw Exception('Refund Address is not a Liquid address');
    }
    // TODO: add label to liquid address
    await _boltzRepo.refundLiquidToLightningSwap(
      swapId: swap.id,
      liquidAddress: address.address,
      absoluteFees: swap.claimFee!,
    );
    // TODO: add label to txid
  }

  Future<void> _processSendBitcoinToLnCoopSign({
    required LnSendSwap swap,
  }) async {
    await _boltzRepo.coopSignBitcoinToLightningSwap(
      swapId: swap.id,
    );
  }

  Future<void> _processSendLiquidToLnCoopSign({
    required Swap swap,
  }) async {
    await _boltzRepo.coopSignLiquidToLightningSwap(
      swapId: swap.id,
    );
  }

  Future<void> _processChainLiquidToBitcoinClaim({
    required ChainSwap swap,
  }) async {
    final claimAddress = await _walletManager.getNewAddress(
      walletId: swap.receiveWalletId!,
    );
    if (!claimAddress.isBitcoin) {
      throw Exception('Claim address is not a Bitcoin address');
    }
    final refundAddress = await _walletManager.getNewAddress(
      walletId: swap.sendWalletId,
    );
    if (!refundAddress.isLiquid) {
      throw Exception('Refund address is not a Liquid address');
    }
    // TODO: add label to bitcoin claim address
    await _boltzRepo.claimLiquidToBitcoinSwap(
      swapId: swap.id,
      absoluteFees: swap.claimFee!,
      bitcoinClaimAddress: claimAddress.address,
      liquidRefundAddress: refundAddress.address,
    );
    // TODO: add label to txid
  }

  Future<void> _processChainBitcoinToLiquidRefund({
    required ChainSwap swap,
  }) async {
    final refundAddress = await _walletManager.getNewAddress(
      walletId: swap.sendWalletId,
    );
    if (!refundAddress.isBitcoin) {
      throw Exception('Refund address is not a Bitcoin address');
    }
    // TODO: add label to bitcoin refund address
    await _boltzRepo.refundBitcoinToLiquidSwap(
      swapId: swap.id,
      absoluteFees: swap.claimFee!,
      bitcoinRefundAddress: refundAddress.address,
    );
    // TODO: add label to txid
  }

  Future<void> _processChainBitcoinToLiquidClaim({
    required ChainSwap swap,
  }) async {
    final claimAddress = await _walletManager.getNewAddress(
      walletId: swap.receiveWalletId!,
    );
    if (!claimAddress.isLiquid) {
      throw Exception('Claim address is not a Liquid address');
    }
    final refundAddress = await _walletManager.getNewAddress(
      walletId: swap.sendWalletId,
    );
    if (!refundAddress.isBitcoin) {
      throw Exception('Refund address is not a Bitcoin address');
    }
    // TODO: add label to bitcoin claim address
    await _boltzRepo.claimBitcoinToLiquidSwap(
      swapId: swap.id,
      absoluteFees: swap.claimFee!,
      liquidClaimAddress: claimAddress.address,
      bitcoinRefundAddress: refundAddress.address,
    );
    // TODO: add label to txid
  }

  Future<void> _processChainLiquidToBitcoinRefund({
    required ChainSwap swap,
  }) async {
    final refundAddress = await _walletManager.getNewAddress(
      walletId: swap.sendWalletId,
    );
    if (!refundAddress.isLiquid) {
      throw Exception('Claim address is not a Liquid address');
    }
    // TODO: add label to liquid refund address
    await _boltzRepo.refundLiquidToBitcoinSwap(
      swapId: swap.id,
      absoluteFees: swap.claimFee!,
      liquidRefundAddress: refundAddress.address,
    );
    // TODO: add label to txid
  }
}
