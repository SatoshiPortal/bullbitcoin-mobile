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

  Future<String> claimLightningToLiquidSwap({
    required String swapId,
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
    required String swapId,
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
    required String swapId,
  });
  Future<String> refundBitcoinToLightningSwap({
    required String swapId,
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
    required String swapId,
  });
  Future<String> refundLiquidToLightningSwap({
    required String swapId,
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
    required String swapId,
    required String bitcoinClaimAddress,
    required String liquidRefundAddress,
    required NetworkFees networkFees,
    required bool tryCooperate,
    required bool broadcastViaBoltz,
  });

  Future<String> claimBitcoinToLiquidSwap({
    required String swapId,
    required String liquidClaimAddress,
    required String bitcoinRefundAddress,
    required NetworkFees networkFees,
    required bool tryCooperate,
    required bool broadcastViaBoltz,
  });

  Future<String> refundLiquidToBitcoinSwap({
    required String swapId,
    required String liquidRefundAddress,
    required NetworkFees networkFees,
    required bool tryCooperate,
    required bool broadcastViaBoltz,
  });

  Future<String> refundBitcoinToLiquidSwap({
    required String swapId,
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
