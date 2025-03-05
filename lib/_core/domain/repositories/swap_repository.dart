import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/swap.dart';
import 'package:boltz/boltz.dart' as boltzLib;

abstract class SwapRepository {
  // FEES
  Future<ReverseSwapFees> getReverseSwapFees();
  Future<SubmarineSwapFees> getSubmarineSwapFees();
  Future<ChainSwapFees> getChainSwapFees();

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
    required String swapId,
    required String liquidAddress,
    required NetworkFees networkFees,
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
  });
  // CHAIN SWAPS
  Future<Swap> createLiquidToBitcoinSwap({
    required String mnemonic,
    required String sendWalletId,
    required int amountSat,
    required Environment environment,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
    String? receiveWalletId,
    String? receipientAddress,
  });

  Future<Swap> createBitcoinToLiquidSwap({
    required String mnemonic,
    required String sendWalletId,
    required int amountSat,
    required Environment environment,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
    String? receiveWalletId,
    String? receipientAddress,
  });

  Future<String> claimLiquidToBitcoinSwap({
    required String swapId,
    required String bitcoinClaimAddress,
    required String liquidRefundAddress,
    required NetworkFees networkFees,
  });

  Future<String> claimBitcoinToLiquidSwap({
    required String swapId,
    required String liquidClaimAddress,
    required String bitcoinRefundAddress,
    required NetworkFees networkFees,
  });

  Future<String> refundLiquidToBitcoinSwap({
    required String swapId,
    required String liquidRefundAddress,
    required NetworkFees networkFees,
  });

  Future<String> refundBitcoinToLiquidSwap({
    required String swapId,
    required String bitcoinRefundAddress,
    required NetworkFees networkFees,
  });

  // SWAP STORAGE UTILITY
  Future<Swap> getSwap({
    required String swapId,
  });

  Future<List<Swap>> getOngoingSwaps();

  Future<void> updateSwap({
    required Swap swap,
  });

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

  Future<(Swap, NextSwapAction)> getBtcLnSwapAndAction({
    required String swapId,
    required String status,
  });

  Future<(Swap, NextSwapAction)> getLbtcLnSwapAndAction({
    required String swapId,
    required String status,
  });

  Future<(Swap, NextSwapAction)> getChainSwapAndAction({
    required String swapId,
    required String status,
  });

  // STREAM
  Stream<boltzLib.SwapStreamStatus> get stream;
  void addSwapToStream({
    required String swapId,
  });
  void removeSwapFromStream({
    required String swapId,
  });
  void reinitializeStreamWithSwaps({
    required List<String> swapIds,
  });
}
