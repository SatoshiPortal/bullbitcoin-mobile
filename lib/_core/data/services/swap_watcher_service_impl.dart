import 'dart:async';

import 'package:bb_mobile/_core/data/repositories/boltz_swap_repository_impl.dart';
import 'package:bb_mobile/_core/domain/entities/swap.dart';
import 'package:bb_mobile/_core/domain/services/swap_watcher_service.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';

class SwapWatcherServiceImpl implements SwapWatcherService {
  final WalletManagerService _walletManager;
  final BoltzSwapRepositoryImpl _boltzRepo;

  StreamSubscription<(String, String)>? _swapSubscription;

  SwapWatcherServiceImpl({
    required WalletManagerService walletManager,
    required BoltzSwapRepositoryImpl boltzRepo,
  })  : _walletManager = walletManager,
        _boltzRepo = boltzRepo {
    startWatching();
  }

  @override
  void startWatching() {
    _swapSubscription = _boltzRepo.stream.listen(
      (tuple) async {
        // tuple is (String, String)
        final swapId = tuple.$1;
        final statusString = tuple.$2;
        await _processSwap(swapId: swapId, status: statusString);
      },
      onError: (error) {
        print('Swap stream error: $error');
      },
      onDone: () {
        print('Swap stream done.');
      },
      cancelOnError: false,
    );
  }

  @override
  Future<void> restartWatcherWithOngoingSwaps() async {
    final swaps = await _boltzRepo.getOngoingSwaps();
    final swapIdsToWatch = swaps.map((swap) => swap.id).toList();
    _boltzRepo.reinitializeStreamWithSwaps(swapIds: swapIdsToWatch);
    startWatching();
  }

  @override
  Future<void> _processSwap({
    required String swapId,
    required String status,
  }) async {
    print("Processing swap $swapId with status $status");
    final swap = await _boltzRepo.getSwap(swapId: swapId);

    switch (swap.type) {
      case SwapType.lightningToBitcoin:
      case SwapType.bitcoinToLightning:
        final updatedSwap = await _boltzRepo.updateBtcLnSwapStatus(
          swapId: swapId,
          boltzStatus: status,
        );
        _processSwapByStatus(updatedSwap);

      case SwapType.lightningToLiquid:
      case SwapType.liquidToLightning:
        final updatedSwap = await _boltzRepo.updateLbtcLnSwapStatus(
          swapId: swapId,
          boltzStatus: status,
        );
        _processSwapByStatus(updatedSwap);

      case SwapType.liquidToBitcoin:
      case SwapType.bitcoinToLiquid:
        final updatedSwap = await _boltzRepo.updateChainSwapStatus(
          swapId: swapId,
          boltzStatus: status,
        );
        _processSwapByStatus(updatedSwap);
    }
    return;
  }

  Future<void> _processSwapByStatus(Swap swap) async {
    switch (swap.status) {
      case SwapStatus.claimable:
        switch (swap.type) {
          case SwapType.lightningToBitcoin:
            await _processReceiveLnToBitcoinClaim(swap: swap);
          case SwapType.lightningToLiquid:
            await _processReceiveLnToLiquidClaim(swap: swap);
          case SwapType.liquidToBitcoin:
            await _processChainLiquidToBitcoinClaim(swap: swap);
          case SwapType.bitcoinToLiquid:
            await _processChainBitcoinToLiquidClaim(swap: swap);
          default:
            return;
        }

      case SwapStatus.refundable:
        switch (swap.type) {
          case SwapType.bitcoinToLightning:
            await _processSendBitcoinToLnRefund(swap: swap);
          case SwapType.liquidToLightning:
            await _processSendLiquidToLnRefund(swap: swap);
          case SwapType.liquidToBitcoin:
            await _processChainLiquidToBitcoinRefund(swap: swap);
          case SwapType.bitcoinToLiquid:
            await _processChainBitcoinToLiquidRefund(swap: swap);
          default:
            return;
        }

      case SwapStatus.canCoop:
        switch (swap.type) {
          case SwapType.bitcoinToLightning:
            await _processSendBitcoinToLnCoopSign(swap: swap);
          case SwapType.liquidToLightning:
            await _processSendLiquidToLnCoopSign(swap: swap);
          default:
            return;
        }

      case SwapStatus.pending:
      case SwapStatus.paid:
      case SwapStatus.completed:
      case SwapStatus.expired:
      case SwapStatus.failed:
        return;
    }
  }

  Future<void> _processReceiveLnToBitcoinClaim({
    required Swap swap,
  }) async {
    // Use maybeMap to ensure we're working with the correct variant
    swap.maybeMap(
      lnReceive: (lnReceiveSwap) async {
        final address = await _walletManager.getNewAddress(
          walletId: lnReceiveSwap.receiveWalletId,
        );
        if (!address.isBitcoin) {
          throw Exception('Claim Address is not a Bitcoin address');
        }
        // TODO: add label to bitcoin address

        final claimTxId = await _boltzRepo.claimLightningToBitcoinSwap(
          swapId: lnReceiveSwap.id,
          absoluteFees: lnReceiveSwap.claimFee!,
          bitcoinAddress: address.address,
        );
        // TODO: add label to txid
      },
      orElse: () =>
          throw Exception('Invalid swap type for LN to Bitcoin claim'),
    );
  }

  Future<void> _processSendBitcoinToLnRefund({
    required Swap swap,
  }) async {
    swap.maybeMap(
      lnSend: (lnSendSwap) async {
        final address = await _walletManager.getNewAddress(
          walletId: lnSendSwap.sendWalletId,
        );
        if (!address.isBitcoin) {
          throw Exception('Refund Address is not a Bitcoin address');
        }
        // TODO: add label to bitcoin address
        final refundTxid = await _boltzRepo.refundBitcoinToLightningSwap(
          swapId: lnSendSwap.id,
          bitcoinAddress: address.address,
          absoluteFees: lnSendSwap.claimFee!,
        );
        // TODO: add label to txid
      },
      orElse: () =>
          throw Exception('Invalid swap type for Bitcoin to LN refund'),
    );
  }

  Future<void> _processReceiveLnToLiquidClaim({
    required Swap swap,
  }) async {
    swap.maybeMap(
      lnReceive: (lnReceiveSwap) async {
        final address = await _walletManager.getNewAddress(
          walletId: lnReceiveSwap.receiveWalletId,
        );
        if (!address.isLiquid) {
          throw Exception('Claim Address is not a Liquid address');
        }
        // TODO: add label to liquid address
        final claimTxId = await _boltzRepo.claimLightningToLiquidSwap(
          swapId: lnReceiveSwap.id,
          absoluteFees: lnReceiveSwap.claimFee!,
          liquidAddress: address.address,
        );
        // TODO: add label to txid
      },
      orElse: () => throw Exception('Invalid swap type for LN to Liquid claim'),
    );
  }

  Future<void> _processSendLiquidToLnRefund({
    required Swap swap,
  }) async {
    swap.maybeMap(
      lnSend: (lnSendSwap) async {
        final address = await _walletManager.getNewAddress(
          walletId: lnSendSwap.sendWalletId,
        );
        if (!address.isLiquid) {
          throw Exception('Refund Address is not a Liquid address');
        }
        // TODO: add label to liquid address
        final refundTxid = await _boltzRepo.refundLiquidToLightningSwap(
          swapId: lnSendSwap.id,
          liquidAddress: address.address,
          absoluteFees: lnSendSwap.claimFee!,
        );
        // TODO: add label to txid
      },
      orElse: () =>
          throw Exception('Invalid swap type for Liquid to LN refund'),
    );
  }

  Future<void> _processSendBitcoinToLnCoopSign({
    required Swap swap,
  }) async {
    swap.maybeMap(
      lnSend: (lnSendSwap) async {
        await _boltzRepo.coopSignBitcoinToLightningSwap(
          swapId: lnSendSwap.id,
        );
      },
      orElse: () =>
          throw Exception('Invalid swap type for Bitcoin to LN coop sign'),
    );
  }

  Future<void> _processSendLiquidToLnCoopSign({
    required Swap swap,
  }) async {
    swap.maybeMap(
      lnSend: (lnSendSwap) async {
        await _boltzRepo.coopSignLiquidToLightningSwap(
          swapId: lnSendSwap.id,
        );
      },
      orElse: () =>
          throw Exception('Invalid swap type for Liquid to LN coop sign'),
    );
  }

  Future<void> _processChainLiquidToBitcoinClaim({
    required Swap swap,
  }) async {
    swap.maybeMap(
      chain: (chainSwap) async {
        if (chainSwap.receiveWalletId == null) {
          throw Exception('Receive wallet ID is missing for chain swap claim');
        }
        final claimAddress = await _walletManager.getNewAddress(
          walletId: chainSwap.receiveWalletId!,
        );
        if (!claimAddress.isBitcoin) {
          throw Exception('Claim address is not a Bitcoin address');
        }
        final refundAddress = await _walletManager.getNewAddress(
          walletId: chainSwap.sendWalletId,
        );
        if (!refundAddress.isLiquid) {
          throw Exception('Refund address is not a Liquid address');
        }
        // TODO: add label to bitcoin claim address
        final claimTxId = await _boltzRepo.claimLiquidToBitcoinSwap(
          swapId: chainSwap.id,
          absoluteFees: chainSwap.claimFee!,
          bitcoinClaimAddress: claimAddress.address,
          liquidRefundAddress: refundAddress.address,
        );
        // TODO: add label to txid
      },
      orElse: () =>
          throw Exception('Invalid swap type for Liquid to Bitcoin claim'),
    );
  }

  Future<void> _processChainBitcoinToLiquidRefund({
    required Swap swap,
  }) async {
    swap.maybeMap(
      chain: (chainSwap) async {
        final refundAddress = await _walletManager.getNewAddress(
          walletId: chainSwap.sendWalletId,
        );
        if (!refundAddress.isBitcoin) {
          throw Exception('Refund address is not a Bitcoin address');
        }
        // TODO: add label to bitcoin refund address
        await _boltzRepo.refundBitcoinToLiquidSwap(
          swapId: chainSwap.id,
          absoluteFees: chainSwap.claimFee!,
          bitcoinRefundAddress: refundAddress.address,
        );
        // TODO: add label to txid
      },
      orElse: () =>
          throw Exception('Invalid swap type for Bitcoin to Liquid refund'),
    );
  }

  Future<void> _processChainBitcoinToLiquidClaim({
    required Swap swap,
  }) async {
    swap.maybeMap(
      chain: (chainSwap) async {
        if (chainSwap.receiveWalletId == null) {
          throw Exception('Receive wallet ID is missing for chain swap claim');
        }
        final claimAddress = await _walletManager.getNewAddress(
          walletId: chainSwap.receiveWalletId!,
        );
        if (!claimAddress.isLiquid) {
          throw Exception('Claim address is not a Liquid address');
        }
        final refundAddress = await _walletManager.getNewAddress(
          walletId: chainSwap.sendWalletId,
        );
        if (!refundAddress.isBitcoin) {
          throw Exception('Refund address is not a Bitcoin address');
        }
        // TODO: add label to bitcoin claim address
        final claimTxId = await _boltzRepo.claimBitcoinToLiquidSwap(
          swapId: chainSwap.id,
          absoluteFees: chainSwap.claimFee!,
          liquidClaimAddress: claimAddress.address,
          bitcoinRefundAddress: refundAddress.address,
        );
        // TODO: add label to txid
      },
      orElse: () =>
          throw Exception('Invalid swap type for Bitcoin to Liquid claim'),
    );
  }

  Future<void> _processChainLiquidToBitcoinRefund({
    required Swap swap,
  }) async {
    swap.maybeMap(
      chain: (chainSwap) async {
        final refundAddress = await _walletManager.getNewAddress(
          walletId: chainSwap.sendWalletId,
        );
        if (!refundAddress.isLiquid) {
          throw Exception('Claim address is not a Liquid address');
        }
        // TODO: add label to liquid refund address
        await _boltzRepo.refundLiquidToBitcoinSwap(
          swapId: chainSwap.id,
          absoluteFees: chainSwap.claimFee!,
          liquidRefundAddress: refundAddress.address,
        );
        // TODO: add label to txid
      },
      orElse: () =>
          throw Exception('Invalid swap type for Liquid to Bitcoin refund'),
    );
  }
}
