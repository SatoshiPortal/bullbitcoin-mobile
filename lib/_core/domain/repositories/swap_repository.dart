import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/swap.dart';
import 'package:boltz/boltz.dart' as boltzLib;

abstract class SwapRepository {
  // LIMITS
  // Future<ReverseSwapFeesAndLimits> getReverseSwapFeesAndLimits();
  // Future<SubmarineSwapFeesAndLimits> getSubmarineSwapFeesAndLimits();
  // Future<ChainSwapFeesAndLimits> getChainSwapFeesAndLimits();

  // RECEIVE SWAPS
  Future<Swap> createLightningToLiquidSwap({
    required String mnemonic,
    required String walletId,
    required int amountSat,
    required bool isTestnet,
    required String electrumUrl,
  });

  // TODO: all claim/refund/coopsign methods can take swap objects instead of swapId strings
  // to avoid having to fetch the swap object again in the method when already done in the processSwap manager method
  Future<String> claimLightningToLiquidSwap({
    required String swapId,
    required String liquidAddress,
    required int absoluteFees,
  });

  Future<Swap> createLightningToBitcoinSwap({
    required String mnemonic,
    required String walletId,
    required int amountSat,
    required bool isTestnet,
    required String electrumUrl,
  });

  Future<String> claimLightningToBitcoinSwap({
    required String swapId,
    required String bitcoinAddress,
    required int absoluteFees,
  });
  // SEND SWAPS
  Future<Swap> createBitcoinToLightningSwap({
    required String mnemonic,
    required String walletId,
    required String invoice,
    required bool isTestnet,
    required String electrumUrl,
  });
  Future<void> coopSignBitcoinToLightningSwap({
    required String swapId,
  });
  Future<String> refundBitcoinToLightningSwap({
    required String swapId,
    required String bitcoinAddress,
    required int absoluteFees,
  });
  Future<Swap> createLiquidToLightningSwap({
    required String mnemonic,
    required String walletId,
    required String invoice,
    required bool isTestnet,
    required String electrumUrl,
  });
  Future<void> coopSignLiquidToLightningSwap({
    required String swapId,
  });
  Future<String> refundLiquidToLightningSwap({
    required String swapId,
    required String liquidAddress,
    required int absoluteFees,
  });
  // CHAIN SWAPS
  Future<Swap> createLiquidToBitcoinSwap({
    required String mnemonic,
    required String sendWalletId,
    required int amountSat,
    required bool isTestnet,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
    String? receiveWalletId,
    String? externalRecipientAddress,
  });

  Future<Swap> createBitcoinToLiquidSwap({
    required String mnemonic,
    required String sendWalletId,
    required int amountSat,
    required bool isTestnet,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
    String? receiveWalletId,
    String? externalRecipientAddress,
  });

  Future<String> claimLiquidToBitcoinSwap({
    required String swapId,
    required String bitcoinClaimAddress,
    required String liquidRefundAddress,
    required int absoluteFees,
  });

  Future<String> claimBitcoinToLiquidSwap({
    required String swapId,
    required String liquidClaimAddress,
    required String bitcoinRefundAddress,
    required int absoluteFees,
  });

  Future<String> refundLiquidToBitcoinSwap({
    required String swapId,
    required String liquidRefundAddress,
    required int absoluteFees,
  });

  Future<String> refundBitcoinToLiquidSwap({
    required String swapId,
    required String bitcoinRefundAddress,
    required int absoluteFees,
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

  Future<Swap> updateBtcLnSwapStatus({
    required String swapId,
    required String boltzStatus,
  });

  Future<Swap> updateLbtcLnSwapStatus({
    required String swapId,
    required String boltzStatus,
  });

  Future<Swap> updateChainSwapStatus({
    required String swapId,
    required String boltzStatus,
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
