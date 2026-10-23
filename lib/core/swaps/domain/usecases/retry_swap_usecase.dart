import 'dart:math';

import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bull_logger/bull_logger.dart';

/// User-triggered "retry now" for a swap whose claim or refund never landed
/// because the background watcher could not reach Boltz.
///
/// Drives the resolve on the **script path only** (cooperative close is never
/// attempted) and broadcasts through the user's own electrum, so it makes **no
/// call to the Boltz API** (api.boltz.exchange): no cooperative signature, no
/// Boltz fee quote, no Boltz broadcast, no outspend lookup. Fees are computed
/// locally from the non-cooperative tx size and the mempool fee estimate,
/// floored at the relay minimum so the tx is always broadcastable even with
/// the fee API down. It does not touch the `SwapWatcher` — the resolve runs
/// directly here — so it works even when the watcher is wedged.
///
/// Returns the refreshed swap so the caller can reflect the new status.
class RetrySwapUsecase {
  final BoltzSwapRepository _boltzSwapRepository;
  final GetNetworkFeesUsecase _getNetworkFeesUsecase;
  final WalletAddressRepository _walletAddressRepository;

  RetrySwapUsecase({
    required this._boltzSwapRepository,
    required this._getNetworkFeesUsecase,
    required this._walletAddressRepository,
  });

  Future<Swap> execute(Swap swap) async {
    try {
      // Reverse swaps are only ever claimed; submarine swaps only refunded;
      // chain swaps claim when the receive leg is pending, refund otherwise.
      final isClaim = switch (swap) {
        LnReceiveSwap() => true,
        LnSendSwap() => false,
        ChainSwap(:final status) => status == SwapStatus.claimable,
      };

      final txid = isClaim ? await _claim(swap) : await _refund(swap);

      log.info('SWAP_RETRY: ${swap.id} resolved via script path, txid=$txid');
      return await _boltzSwapRepository.getSwap(swapId: swap.id);
    } catch (e) {
      log.warning('SWAP_RETRY: ${swap.id} script-path retry failed: $e');
      throw RetrySwapException('$e');
    }
  }

  Future<String> _claim(Swap swap) async {
    final claimAddress = await _resolveClaimAddress(swap);
    final isLiquid = _claimOnLiquid(swap.type);
    final txSize = await _boltzSwapRepository.getSwapClaimTxSize(
      swapId: swap.id,
      swapType: swap.type,
      isCooperative: false,
      claimAddressForChainSwaps: swap is ChainSwap ? claimAddress : null,
    );
    final absoluteFees = await _scriptPathFees(
      txSize: txSize,
      isLiquid: isLiquid,
    );

    final txid = switch (swap.type) {
      SwapType.lightningToBitcoin =>
        await _boltzSwapRepository.claimLightningToBitcoinSwap(
          swapId: swap.id,
          bitcoinAddress: claimAddress,
          absoluteFees: absoluteFees,
          cooperate: false,
        ),
      SwapType.lightningToLiquid =>
        await _boltzSwapRepository.claimLightningToLiquidSwap(
          swapId: swap.id,
          liquidAddress: claimAddress,
          absoluteFees: absoluteFees,
          cooperate: false,
        ),
      SwapType.bitcoinToLiquid =>
        await _boltzSwapRepository.claimBitcoinToLiquidSwap(
          swapId: swap.id,
          liquidClaimAddress: claimAddress,
          absoluteFees: absoluteFees,
          cooperate: false,
        ),
      SwapType.liquidToBitcoin =>
        await _boltzSwapRepository.claimLiquidToBitcoinSwap(
          swapId: swap.id,
          bitcoinClaimAddress: claimAddress,
          absoluteFees: absoluteFees,
          cooperate: false,
        ),
      SwapType.bitcoinToLightning ||
      SwapType.liquidToLightning => throw RetrySwapException(
        'submarine swap ${swap.id} has no claim transaction',
      ),
    };

    await _boltzSwapRepository.updateSwapFields(
      swap.id,
      status: SwapStatus.completed,
      receiveTxid: txid,
      receiveAddress: claimAddress,
      claimFee: absoluteFees,
      completionTime: DateTime.now(),
    );
    return txid;
  }

  Future<String> _refund(Swap swap) async {
    final refundAddress = await _resolveRefundAddress(swap);
    final isLiquid = _refundOnLiquid(swap.type);
    final txSize = await _boltzSwapRepository.getSwapRefundTxSize(
      swapId: swap.id,
      swapType: swap.type,
      isCooperative: false,
      refundAddressForChainSwaps: swap is ChainSwap ? refundAddress : null,
    );
    final absoluteFees = await _scriptPathFees(
      txSize: txSize,
      isLiquid: isLiquid,
    );

    final txid = switch (swap.type) {
      SwapType.bitcoinToLightning =>
        await _boltzSwapRepository.refundBitcoinToLightningSwap(
          swapId: swap.id,
          bitcoinAddress: refundAddress,
          absoluteFees: absoluteFees,
          cooperate: false,
        ),
      SwapType.liquidToLightning =>
        await _boltzSwapRepository.refundLiquidToLightningSwap(
          swapId: swap.id,
          liquidAddress: refundAddress,
          absoluteFees: absoluteFees,
          cooperate: false,
        ),
      SwapType.bitcoinToLiquid =>
        await _boltzSwapRepository.refundBitcoinToLiquidSwap(
          swapId: swap.id,
          bitcoinRefundAddress: refundAddress,
          absoluteFees: absoluteFees,
          cooperate: false,
        ),
      SwapType.liquidToBitcoin =>
        await _boltzSwapRepository.refundLiquidToBitcoinSwap(
          swapId: swap.id,
          liquidRefundAddress: refundAddress,
          absoluteFees: absoluteFees,
          cooperate: false,
        ),
      SwapType.lightningToBitcoin ||
      SwapType.lightningToLiquid => throw RetrySwapException(
        'reverse swap ${swap.id} has no refund transaction',
      ),
    };

    await _boltzSwapRepository.updateSwapFields(
      swap.id,
      status: SwapStatus.refunded,
      refundTxid: txid,
      refundAddress: refundAddress,
      refundFee: absoluteFees,
      completionTime: DateTime.now(),
    );
    return txid;
  }

  /// The claim pays into the user's receive side: the address stored at
  /// creation, or a fresh one from the receive wallet when none was kept.
  Future<String> _resolveClaimAddress(Swap swap) async {
    final existing = swap.receiveAddress;
    if (existing != null && existing.isNotEmpty) return existing;
    final walletId = switch (swap) {
      LnReceiveSwap(:final receiveWalletId) => receiveWalletId,
      ChainSwap(:final receiveWalletId) => receiveWalletId,
      _ => null,
    };
    if (walletId == null) {
      throw RetrySwapException('swap ${swap.id} has no wallet to claim into');
    }
    final address = await _walletAddressRepository.generateNewReceiveAddress(
      walletId: walletId,
    );
    return address.address;
  }

  /// The refund returns the locked funds to the user's send wallet: the
  /// address stored on the swap, or a fresh one persisted back for the retry.
  Future<String> _resolveRefundAddress(Swap swap) async {
    final existing = switch (swap) {
      LnSendSwap(:final refundAddress) => refundAddress,
      ChainSwap(:final refundAddress) => refundAddress,
      _ => null,
    };
    if (existing != null && existing.isNotEmpty) return existing;
    final walletId = switch (swap) {
      LnSendSwap(:final sendWalletId) => sendWalletId,
      ChainSwap(:final sendWalletId) => sendWalletId,
      _ => null,
    };
    if (walletId == null) {
      throw RetrySwapException('swap ${swap.id} has no wallet to refund into');
    }
    final address = await _walletAddressRepository.generateNewReceiveAddress(
      walletId: walletId,
    );
    await _boltzSwapRepository.updateSwapFields(
      swap.id,
      refundAddress: address.address,
    );
    return address.address;
  }

  /// Live mempool fee for [txSize], floored at the relay minimum. When the fee
  /// estimate is unreachable (this path must work with every service but the
  /// user's electrum down), falls back to the relay-floor fee itself: always
  /// broadcastable, and on Liquid the floor is the normal rate anyway.
  Future<int> _scriptPathFees({
    required int txSize,
    required bool isLiquid,
  }) async {
    final floor = _relayFloor(txSize: txSize, isLiquid: isLiquid);
    try {
      final fees = await _getNetworkFeesUsecase.execute(isLiquid: isLiquid);
      final absolute = fees.toAbsolute(txSize).fastest.value.toInt();
      return max(absolute, floor);
    } catch (e) {
      log.warning(
        'SWAP_RETRY: fee estimate unavailable ($e); using relay floor $floor '
        'for txSize=$txSize',
      );
      return floor;
    }
  }

  // Liquid floors at 0.1 sat/vb (plus discount-CT padding), Bitcoin at 1 sat/vb.
  int _relayFloor({required int txSize, required bool isLiquid}) =>
      isLiquid ? (txSize * 0.11).ceil() + 1 : txSize;

  // The claim is broadcast on the RECEIVE chain.
  bool _claimOnLiquid(SwapType type) => switch (type) {
    SwapType.lightningToLiquid || SwapType.bitcoinToLiquid => true,
    SwapType.lightningToBitcoin || SwapType.liquidToBitcoin => false,
    SwapType.bitcoinToLightning || SwapType.liquidToLightning => false,
  };

  // The refund is broadcast on the SEND chain.
  bool _refundOnLiquid(SwapType type) => switch (type) {
    SwapType.liquidToLightning || SwapType.liquidToBitcoin => true,
    SwapType.bitcoinToLightning || SwapType.bitcoinToLiquid => false,
    SwapType.lightningToBitcoin || SwapType.lightningToLiquid => false,
  };
}

class RetrySwapException extends BullException {
  RetrySwapException(super.message);
}
