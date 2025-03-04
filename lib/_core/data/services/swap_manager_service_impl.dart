import 'package:bb_mobile/_core/data/repositories/boltz_swap_repository_impl.dart';
import 'package:bb_mobile/_core/domain/entities/swap.dart';
import 'package:bb_mobile/_core/domain/services/swap_manager_service.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';
import 'package:boltz/boltz.dart' as boltzLib;

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

    final swap = await _boltzRepo.getSwapById(swapId: swapId);
    switch (swap.type) {
      case SwapType.lightningToBitcoin:
      case SwapType.bitcoinToLightning:
        final (btcLnSwap, action) = await _boltzRepo.getBtcLnSwapAndAction(
          swapId: swapId,
          status: status,
        );
        switch (action) {
          case NextSwapAction.wait:
            return;
          case NextSwapAction.claim:
            await _processReceiveBtcClaim(
              bitcoinAddress: 'bc1k',
              networkFees: const NetworkFees.relative(1.0),
              btcLnSwap: btcLnSwap,
              tryCooperate: true,
            );
          case NextSwapAction.coopSign:
            await _processSendBtcCoopSign(
              btcLnSwap: btcLnSwap,
            );
          case NextSwapAction.refund:
            await _processSendBtcRefund(
              bitcoinAddress: 'bc1k',
              networkFees: const NetworkFees.relative(1.0),
              btcLnSwap: btcLnSwap,
              tryCooperate: true,
            );
          case NextSwapAction.close:
          // TODO: Close swap repository method
          // TODO: Stop listening to swap ID in stream
        }
      case SwapType.lightningToLiquid:
      case SwapType.liquidToLightning:
        final (lbtcLnSwap, action) = await _boltzRepo.getLbtcLnSwapAndAction(
          swapId: swapId,
          status: status,
        );
        switch (action) {
          case NextSwapAction.wait:
            return;
          case NextSwapAction.claim:
            await _processReceiveLBtcClaim(
              liquidAddress: 'lq1k',
              networkFees: const NetworkFees.relative(1.0),
              lbtcLnSwap: lbtcLnSwap,
              tryCooperate: true,
            );
          case NextSwapAction.coopSign:
            await _processSendLbtcCoopSign(
              lbtcLnSwap: lbtcLnSwap,
            );
          case NextSwapAction.refund:
            await _processSendLbtcRefund(
              liquidAddress: 'lq1k',
              networkFees: const NetworkFees.relative(1.0),
              lbtcLnSwap: lbtcLnSwap,
              tryCooperate: true,
            );
          case NextSwapAction.close:
          // TODO: Close swap repository method
          // TODO: Stop listening to swap ID in stream
        }
      case SwapType.liquidToBitcoin:
        final (chainSwap, action) = await _boltzRepo.getChainSwapAndAction(
          swapId: swapId,
          status: status,
        );
        switch (action) {
          case NextSwapAction.wait:
            return;
          case NextSwapAction.claim:
            await _processChainBtcClaim(
              chainSwap: chainSwap,
              networkFees: const NetworkFees.relative(1.0),
              tryCooperate: true,
              bitcoinClaimAddress: 'bc1k',
              liquidRefundAddress: 'lq1k',
            );
          case NextSwapAction.coopSign:
            return;
          case NextSwapAction.refund:
            await _processChainLbtcRefund(
              chainSwap: chainSwap,
              networkFees: const NetworkFees.relative(1.0),
              tryCooperate: true,
              liquidRefundAddress: 'lq1k',
            );
          case NextSwapAction.close:
          // TODO: Close swap repository method
          // TODO: Stop listening to swap ID in stream
        }
      case SwapType.bitcoinToLiquid:
        final (chainSwap, action) = await _boltzRepo.getChainSwapAndAction(
          swapId: swapId,
          status: status,
        );
        switch (action) {
          case NextSwapAction.wait:
            return;
          case NextSwapAction.claim:
            await _processChainLbtcClaim(
              chainSwap: chainSwap,
              networkFees: const NetworkFees.relative(1.0),
              tryCooperate: true,
              liquidClaimAddress: 'lq1k',
              bitcoinRefundAddress: 'bc1k',
            );
          case NextSwapAction.coopSign:
            return;
          case NextSwapAction.refund:
            await _processChainBtcRefund(
              chainSwap: chainSwap,
              networkFees: const NetworkFees.relative(1.0),
              tryCooperate: true,
              bitcoinRefundAddress: 'bc1k',
            );
          // TODO: add label to txid
          case NextSwapAction.close:
          // TODO: Close swap repository method
          // TODO: Stop listening to swap ID in stream
        }
    }
    return;
  }

  Future<void> _processReceiveBtcClaim({
    required boltzLib.BtcLnSwap btcLnSwap,
    required NetworkFees networkFees,
    required bool tryCooperate,
    required String bitcoinAddress,
  }) async {
    // TODO: get bitcoin address
    // TODO: add label to bitcoin address
    // TODO: get network fees
    final claimTxId = await _boltzRepo.claimLightningToBitcoinSwap(
      btcLnSwap: btcLnSwap,
      networkFees: networkFees,
      tryCooperate: tryCooperate,
      broadcastViaBoltz: false,
      bitcoinAddress: bitcoinAddress,
    );
    // TODO: add label to txid
  }

  Future<void> _processSendBtcRefund({
    required boltzLib.BtcLnSwap btcLnSwap,
    required NetworkFees networkFees,
    required bool tryCooperate,
    required String bitcoinAddress,
  }) async {
    // TODO: get bitcoin address
    // TODO: add label to bitcoin address
    // TODO: get network fees
    final refundTxid = await _boltzRepo.refundBitcoinToLightningSwap(
      btcLnSwap: btcLnSwap,
      bitcoinAddress: bitcoinAddress,
      networkFees: networkFees,
      tryCooperate: tryCooperate,
      broadcastViaBoltz: false,
    );
    // TODO: add label to txid
  }

  Future<void> _processReceiveLBtcClaim({
    required boltzLib.LbtcLnSwap lbtcLnSwap,
    required NetworkFees networkFees,
    required bool tryCooperate,
    required String liquidAddress,
  }) async {
    // TODO: get liquid address
    // TODO: add label to liquid address
    // TODO: get network fees
    final claimTxId = await _boltzRepo.claimLightningToLiquidSwap(
      lbtcLnSwap: lbtcLnSwap,
      networkFees: networkFees,
      tryCooperate: true,
      broadcastViaBoltz: false,
      liquidAddress: liquidAddress,
    );
    // TODO: add label to txid
  }

  Future<void> _processSendLbtcRefund({
    required boltzLib.LbtcLnSwap lbtcLnSwap,
    required NetworkFees networkFees,
    required bool tryCooperate,
    required String liquidAddress,
  }) async {
    // TODO: get liquid address
    // TODO: add label to liquid address
    // TODO: get network fees
    final refundTxid = await _boltzRepo.refundLiquidToLightningSwap(
      lbtcLnSwap: lbtcLnSwap,
      liquidAddress: liquidAddress,
      networkFees: networkFees,
      tryCooperate: tryCooperate,
      broadcastViaBoltz: false,
    );
    // TODO: add label to txid
  }

  Future<void> _processSendBtcCoopSign({
    required boltzLib.BtcLnSwap btcLnSwap,
  }) async {
    await _boltzRepo.coopSignBitcoinToLightningSwap(
      btcLnSwap: btcLnSwap,
    );
  }

  Future<void> _processSendLbtcCoopSign({
    required boltzLib.LbtcLnSwap lbtcLnSwap,
  }) async {
    await _boltzRepo.coopSignLiquidToLightningSwap(
      lbtcLnSwap: lbtcLnSwap,
    );
  }

  Future<void> _processChainBtcClaim({
    required boltzLib.ChainSwap chainSwap,
    required NetworkFees networkFees,
    required bool tryCooperate,
    required String bitcoinClaimAddress,
    required String liquidRefundAddress,
  }) async {
    // TODO: get bitcoin claim address
    // TODO: get liquid refund address
    // TODO: add label to bitcoin claim address
    // TODO: get network fees
    final claimTxId = await _boltzRepo.claimLiquidToBitcoinSwap(
      chainSwap: chainSwap,
      networkFees: networkFees,
      tryCooperate: tryCooperate,
      broadcastViaBoltz: false,
      bitcoinClaimAddress: bitcoinClaimAddress,
      liquidRefundAddress: liquidRefundAddress,
    );
    // TODO: add label to txid
  }

  Future<void> _processChainBtcRefund({
    required boltzLib.ChainSwap chainSwap,
    required NetworkFees networkFees,
    required bool tryCooperate,
    required String bitcoinRefundAddress,
  }) async {
    // TODO: get bitcoin refund address
    // TODO: add label to bitcoin refund address
    // TODO: get network fees
    await _boltzRepo.refundBitcoinToLiquidSwap(
      chainSwap: chainSwap,
      networkFees: networkFees,
      tryCooperate: tryCooperate,
      broadcastViaBoltz: false,
      bitcoinRefundAddress: bitcoinRefundAddress,
    );
    // TODO: add label to txid
  }

  Future<void> _processChainLbtcClaim({
    required boltzLib.ChainSwap chainSwap,
    required NetworkFees networkFees,
    required bool tryCooperate,
    required String liquidClaimAddress,
    required String bitcoinRefundAddress,
  }) async {
    // TODO: get bitcoin claim address
    // TODO: get liquid refund address
    // TODO: add label to bitcoin claim address
    // TODO: get network fees
    final claimTxId = await _boltzRepo.claimBitcoinToLiquidSwap(
      chainSwap: chainSwap,
      networkFees: networkFees,
      tryCooperate: tryCooperate,
      broadcastViaBoltz: false,
      liquidClaimAddress: liquidClaimAddress,
      bitcoinRefundAddress: bitcoinRefundAddress,
    );
    // TODO: add label to txid
  }

  Future<void> _processChainLbtcRefund({
    required boltzLib.ChainSwap chainSwap,
    required NetworkFees networkFees,
    required bool tryCooperate,
    required String liquidRefundAddress,
  }) async {
    // TODO: get liquid refund address
    // TODO: add label to liquid refund address
    // TODO: get network fees
    await _boltzRepo.refundLiquidToBitcoinSwap(
      chainSwap: chainSwap,
      networkFees: networkFees,
      tryCooperate: tryCooperate,
      broadcastViaBoltz: false,
      liquidRefundAddress: liquidRefundAddress,
    );
    // TODO: add label to txid
  }
}
