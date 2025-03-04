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
            // TODO: get bitcoin address
            // TODO: add label to bitcoin address
            // TODO: get network fees
            final claimTxId = await _boltzRepo.claimLightningToBitcoinSwap(
              swapId: swapId,
              networkFees: const NetworkFees.relative(1.0),
              tryCooperate: true,
              broadcastViaBoltz: false,
              bitcoinAddress: 'bc1k',
            );
          // TODO: add label to txid
          case NextSwapAction.coopSign:
            await _boltzRepo.coopSignBitcoinToLightningSwap(
              swapId: swapId,
            );
          case NextSwapAction.refund:
            // TODO: get bitcoin address
            // TODO: add label to bitcoin address
            // TODO: get network fees
            await _boltzRepo.refundBitcoinToLightningSwap(
              swapId: swapId,
              bitcoinAddress: 'bc1k',
              networkFees: const NetworkFees.relative(1.0),
              tryCooperate: true,
              broadcastViaBoltz: false,
            );
          // TODO: add label to txid

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
            // TODO: get liquid address
            // TODO: add label to liquid address
            // TODO: get network fees
            final claimTxId = await _boltzRepo.claimLightningToLiquidSwap(
              swapId: swapId,
              networkFees: const NetworkFees.relative(1.0),
              tryCooperate: true,
              broadcastViaBoltz: false,
              liquidAddress: 'lq1k',
            );
          // TODO: add label to txid
          case NextSwapAction.coopSign:
            await _boltzRepo.coopSignLiquidToLightningSwap(
              swapId: swapId,
            );
          case NextSwapAction.refund:
            // TODO: get liquid address
            // TODO: add label to liquid address
            // TODO: get network fees
            await _boltzRepo.refundLiquidToLightningSwap(
              swapId: swapId,
              liquidAddress: 'lq1k',
              networkFees: const NetworkFees.relative(1.0),
              tryCooperate: true,
              broadcastViaBoltz: false,
            );
          // TODO: add label to txid

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
            // TODO: get bitcoin claim address
            // TODO: get liquid refund address
            // TODO: add label to bitcoin claim address
            // TODO: get network fees
            final claimTxId = await _boltzRepo.claimLiquidToBitcoinSwap(
              swapId: swapId,
              networkFees: const NetworkFees.relative(1.0),
              tryCooperate: true,
              broadcastViaBoltz: false,
              bitcoinClaimAddress: 'bc1k',
              liquidRefundAddress: 'lq1k',
            );
          // TODO: add label to txid
          case NextSwapAction.coopSign:
          // NEVER A CASE FOR CHAIN SWAPS COOP SIGNING TAKES PLACE INTERNALLY
          case NextSwapAction.refund:
            // TODO: get liquid refund address
            // TODO: add label to liquid refund address
            // TODO: get network fees
            await _boltzRepo.refundLiquidToBitcoinSwap(
              swapId: swapId,
              networkFees: const NetworkFees.relative(1.0),
              tryCooperate: true,
              broadcastViaBoltz: false,
              liquidRefundAddress: 'lq1k',
            );
          // TODO: add label to txid

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
            // TODO: get liquid claim address and bitcoin refund address
            // TODO: add label to liquid claim address
            // TODO: get network fees

            final claimTxId = await _boltzRepo.claimBitcoinToLiquidSwap(
              swapId: swapId,
              networkFees: const NetworkFees.relative(1.0),
              tryCooperate: true,
              broadcastViaBoltz: false,
              liquidClaimAddress: 'lq1k',
              bitcoinRefundAddress: 'bc1k',
            );
          // TODO: add label to txid
          case NextSwapAction.coopSign:
          // NEVER A CASE FOR CHAIN SWAPS COOP SIGNING TAKES PLACE INTERNALLY
          case NextSwapAction.refund:
            // TODO: get bitcoin refund address
            // TODO: add label to bitcoin  refund address
            // TODO: get network fees
            await _boltzRepo.refundBitcoinToLiquidSwap(
              swapId: swapId,
              networkFees: const NetworkFees.relative(1.0),
              tryCooperate: true,
              broadcastViaBoltz: false,
              bitcoinRefundAddress: '',
            );
          // TODO: add label to txid

          case NextSwapAction.close:
          // TODO: Close swap repository method
          // TODO: Stop listening to swap ID in stream
        }
    }
    return;
  }
}
