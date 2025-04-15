import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/lightning.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';

class CreateSendSwapUsecase {
  final WalletRepository _walletRepository;
  final SwapRepository _swapRepository;
  final SwapRepository _swapRepositoryTestnet;
  final SeedRepository _seedRepository;

  CreateSendSwapUsecase({
    required WalletRepository walletRepository,
    required SwapRepository swapRepository,
    required SwapRepository swapRepositoryTestnet,
    required SeedRepository seedRepository,
  })  : _walletRepository = walletRepository,
        _swapRepository = swapRepository,
        _swapRepositoryTestnet = swapRepositoryTestnet,
        _seedRepository = seedRepository;

  Future<LnSendSwap> execute({
    required String origin,
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
      final finalInvoice = invoice ??
          await invoiceFromLnAddress(
            lnAddress: lnAddress!,
            amountSat: amountSat!,
          );
      final wallet = await _walletRepository.getWallet(origin);
      final swapRepository =
          wallet.network.isTestnet ? _swapRepositoryTestnet : _swapRepository;
      final decoded = await swapRepository.decodeInvoice(invoice: finalInvoice);

      final limits = await _swapRepository.getSwapLimits(type: type);
      if (decoded.sats < limits.min) {
        throw Exception('Minimum Swap Amount: $limits.min sats');
      }
      if (decoded.sats > limits.max) {
        throw Exception('Maximum Swap Amount: $limits.max sats');
      }

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

      final btcElectrumUrl = wallet.network.isTestnet
          ? ApiServiceConstants.bbElectrumTestUrl
          : ApiServiceConstants.bbElectrumUrl;

      final lbtcElectrumUrl = wallet.network.isTestnet
          ? ApiServiceConstants.publicElectrumTestUrl
          : ApiServiceConstants.bbLiquidElectrumUrlPath;

      switch (type) {
        case SwapType.bitcoinToLightning:
          return await swapRepository.createBitcoinToLightningSwap(
            origin: origin,
            invoice: finalInvoice,
            isTestnet: wallet.network.isTestnet,
            mnemonic: mnemonic.mnemonicWords.join(' '),
            electrumUrl: btcElectrumUrl,
          );

        case SwapType.liquidToLightning:
          return await swapRepository.createLiquidToLightningSwap(
            origin: origin,
            invoice: finalInvoice,
            isTestnet: wallet.network.isTestnet,
            mnemonic: mnemonic.mnemonicWords.join(' '),
            electrumUrl: lbtcElectrumUrl,
          );
        default:
          throw Exception('This is not a swap for the receive feature!');
      }
    } catch (e) {
      rethrow;
    }
  }
}
