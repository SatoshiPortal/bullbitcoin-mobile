import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/swap.dart';
import 'package:boltz/boltz.dart';

abstract class SwapRepository {
  // RECEIVE SWAPS
  Future<Swap> createLightningToLiquidSwap({
    required String mnemonic,
    required String walletId,
    required int amountSat,
    required Environment environment,
    required String electrumUrl,
  });

  // TODO: all claim/refund/coopsign methods can take swap objects instead of swapId strings
  // to avoid having to fetch the swap object again in the method when already done in the processSwap manager method
  Future<String> claimLightningToLiquidSwap({
    required LbtcLnSwap lbtcLnSwap,
    required String liquidAddress,
    required NetworkFees networkFees,
    required bool tryCooperate,
    required bool broadcastViaBoltz,
  });

  Future<Swap> createLightningToBitcoinSwap({
    required String mnemonic,
    required String walletId,
    required int amountSat,
    required Environment environment,
    required String electrumUrl,
  });

  Future<String> claimLightningToBitcoinSwap({
    required BtcLnSwap btcLnSwap,
    required String bitcoinAddress,
    required NetworkFees networkFees,
    required bool tryCooperate,
    required bool broadcastViaBoltz,
  });
  // SEND SWAPS
  Future<Swap> createBitcoinToLightningSwap({
    required String mnemonic,
    required String walletId,
    required String invoice,
    required Environment environment,
    required String electrumUrl,
  });
  Future<void> coopSignBitcoinToLightningSwap({
    required BtcLnSwap btcLnSwap,
  });
  Future<String> refundBitcoinToLightningSwap({
    required BtcLnSwap btcLnSwap,
    required String bitcoinAddress,
    required NetworkFees networkFees,
    required bool tryCooperate,
    required bool broadcastViaBoltz,
  });
  Future<Swap> createLiquidToLightningSwap({
    required String mnemonic,
    required String walletId,
    required String invoice,
    required Environment environment,
    required String electrumUrl,
  });
  Future<void> coopSignLiquidToLightningSwap({
    required LbtcLnSwap lbtcLnSwap,
  });
  Future<String> refundLiquidToLightningSwap({
    required LbtcLnSwap lbtcLnSwap,
    required String liquidAddress,
    required NetworkFees networkFees,
    required bool tryCooperate,
    required bool broadcastViaBoltz,
  });
  // CHAIN SWAPS
  Future<Swap> createLiquidToBitcoinSwap({
    required String mnemonic,
    required String sendWalletId,
    required int amountSat,
    required Environment environment,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
    required bool toSelf,
    String? receiveWalletId,
  });

  Future<Swap> createBitcoinToLiquidSwap({
    required String mnemonic,
    required String sendWalletId,
    required int amountSat,
    required Environment environment,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
    required bool toSelf,
    String? receiveWalletId,
  });

  Future<String> claimLiquidToBitcoinSwap({
    required ChainSwap chainSwap,
    required String bitcoinClaimAddress,
    required String liquidRefundAddress,
    required NetworkFees networkFees,
    required bool tryCooperate,
    required bool broadcastViaBoltz,
  });

  Future<String> claimBitcoinToLiquidSwap({
    required ChainSwap chainSwap,
    required String liquidClaimAddress,
    required String bitcoinRefundAddress,
    required NetworkFees networkFees,
    required bool tryCooperate,
    required bool broadcastViaBoltz,
  });

  Future<String> refundLiquidToBitcoinSwap({
    required ChainSwap chainSwap,
    required String liquidRefundAddress,
    required NetworkFees networkFees,
    required bool tryCooperate,
    required bool broadcastViaBoltz,
  });

  Future<String> refundBitcoinToLiquidSwap({
    required ChainSwap chainSwap,
    required String bitcoinRefundAddress,
    required NetworkFees networkFees,
    required bool tryCooperate,
    required bool broadcastViaBoltz,
  });

  // SWAP STORAGE UTILITY
  Future<void> updatePaidSendSwap({
    required String swapId,
    required String txid,
  });

  Future<void> updateExpiredSwap({
    required String swapId,
  });

  Future<void> updateFailedSwap({
    required String swapId,
  });

  Future<Swap> getSwapById({
    required String swapId,
  });

  Future<(BtcLnSwap, NextSwapAction)> getBtcLnSwapAndAction({
    required String swapId,
    required String status,
  });

  Future<(LbtcLnSwap, NextSwapAction)> getLbtcLnSwapAndAction({
    required String swapId,
    required String status,
  });

  Future<(ChainSwap, NextSwapAction)> getChainSwapAndAction({
    required String swapId,
    required String status,
  });

  // STREAM
  Stream<SwapStreamStatus> get stream;
}
