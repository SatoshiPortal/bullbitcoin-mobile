import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet_transaction/domain/entities/wallet_transaction.dart';

abstract class SwapRepository {
  // LIMITS
  Future<SwapLimits> getSwapLimits({
    required SwapType type,
  });

  // RECEIVE SWAPS
  Future<LnReceiveSwap> createLightningToLiquidSwap({
    required String mnemonic,
    required String walletId,
    required int amountSat,
    required bool isTestnet,
    required String electrumUrl,
    required String claimAddress,
    String? description,
  });

  Future<String> claimLightningToLiquidSwap({
    required String swapId,
    required String liquidAddress,
    required int absoluteFees,
  });

  Future<LnReceiveSwap> createLightningToBitcoinSwap({
    required String mnemonic,
    required String walletId,
    required int amountSat,
    required bool isTestnet,
    required String electrumUrl,
    required String claimAddress,
    String? description,
  });

  Future<String> claimLightningToBitcoinSwap({
    required String swapId,
    required String bitcoinAddress,
    required int absoluteFees,
  });
  // SEND SWAPS
  Future<LnSendSwap> createBitcoinToLightningSwap({
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
  Future<LnSendSwap> createLiquidToLightningSwap({
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

  Future<Invoice> decodeInvoice({
    required String invoice,
  });

  Future<String> invoiceFromLnAddress({
    required String lnAddress,
    required int amountSat,
  });

  // SWAP STORAGE UTILITY
  Future<Swap> getSwap({
    required String swapId,
  });
  Future<List<Swap>> getOngoingSwaps();
  Future<List<Swap>> getAllSwaps();

  Future<void> updateSwap({
    required Swap swap,
  });

  Future<void> updatePaidSendSwap({
    required String swapId,
    required String txid,
  });

  Future<Transaction?> getSwapWalletTx({
    required WalletTransaction baseWalletTx,
    required Network network,
  });

  // STREAM
  Future<void> reinitializeStreamWithSwaps({
    required List<String> swapIds,
  });

  // Add a method to subscribe to swap updates
  Stream<Swap> get swapUpdatesStream;
}
