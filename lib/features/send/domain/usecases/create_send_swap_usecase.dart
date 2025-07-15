import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/lightning.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class CreateSendSwapUsecase {
  final WalletRepository _walletRepository;
  final BoltzSwapRepository _swapRepository;
  final BoltzSwapRepository _swapRepositoryTestnet;
  final SeedRepository _seedRepository;

  CreateSendSwapUsecase({
    required WalletRepository walletRepository,
    required BoltzSwapRepository swapRepository,
    required BoltzSwapRepository swapRepositoryTestnet,
    required SeedRepository seedRepository,
  }) : _walletRepository = walletRepository,
       _swapRepository = swapRepository,
       _swapRepositoryTestnet = swapRepositoryTestnet,
       _seedRepository = seedRepository;

  Future<LnSendSwap> execute({
    required String walletId,
    required SwapType type,
    String? invoice,
    String? lnAddress,
    int? amountSat,
  }) async {
    try {
      if (invoice == null && lnAddress == null) {
        throw Exception('Invoice or lnAddress must be provided');
      }
      if (amountSat == null && lnAddress != null) {
        throw Exception('Amount must be provided if lnAddress is used');
      }
      final finalInvoice =
          invoice?.toLowerCase() ??
          await invoiceFromLnAddress(
            lnAddress: lnAddress!,
            amountSat: amountSat!,
          );
      final wallet = await _walletRepository.getWallet(walletId);

      if (wallet == null) {
        throw Exception('Wallet not found');
      }

      final swapRepository =
          wallet.network.isTestnet ? _swapRepositoryTestnet : _swapRepository;

      final existingSwap = await swapRepository.getSendSwapByInvoice(
        invoice: finalInvoice,
      );
      if (existingSwap != null) return existingSwap;

      final mnemonic =
          await _seedRepository.get(wallet.masterFingerprint) as MnemonicSeed;

      if (wallet.network.isLiquid && type != SwapType.liquidToLightning) {
        throw Exception(
          'Liquid wallet must be used for a liquid to lightning swap',
        );
      }
      if (wallet.network.isBitcoin && type != SwapType.bitcoinToLightning) {
        throw Exception(
          'Bitcoin wallet must be used for a liquid to lightning swap',
        );
      }

      final btcElectrumUrl =
          wallet.network.isTestnet
              ? ApiServiceConstants.bbElectrumTestUrl
              : ApiServiceConstants.bbElectrumUrl;

      final lbtcElectrumUrl =
          wallet.network.isTestnet
              ? ApiServiceConstants.publicElectrumTestUrl
              : ApiServiceConstants.bbLiquidElectrumUrlPath;

      switch (type) {
        case SwapType.bitcoinToLightning:
          return await swapRepository.createBitcoinToLightningSwap(
            walletId: walletId,
            invoice: finalInvoice,
            mnemonic: mnemonic.mnemonicWords.join(' '),
            electrumUrl: btcElectrumUrl,
          );

        case SwapType.liquidToLightning:
          return await swapRepository.createLiquidToLightningSwap(
            walletId: walletId,
            invoice: finalInvoice,
            mnemonic: mnemonic.mnemonicWords.join(' '),
            electrumUrl: lbtcElectrumUrl,
          );
        default:
          throw Exception('This is not a swap for the send feature!');
      }
    } catch (e) {
      rethrow;
    }
  }
}

// _$BoltzErrorImpl (BoltzError(kind: HTTP, message: "a swap with this invoice exists already"))
