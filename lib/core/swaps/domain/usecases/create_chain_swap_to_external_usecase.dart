import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class CreateChainSwapToExternalUsecase {
  final WalletRepository _walletRepository;
  final BoltzSwapRepository _swapRepository;
  final BoltzSwapRepository _swapRepositoryTestnet;

  CreateChainSwapToExternalUsecase({
    required WalletRepository walletRepository,
    required BoltzSwapRepository swapRepository,
    required BoltzSwapRepository swapRepositoryTestnet,
  }) : _walletRepository = walletRepository,
       _swapRepository = swapRepository,
       _swapRepositoryTestnet = swapRepositoryTestnet;

  Future<ChainSwap> execute({
    required String sendWalletId,
    required String receiveAddress,
    required SwapType type,
    required int amountSat,
  }) async {
    try {
      final sendWallet = await _walletRepository.getWallet(sendWalletId);

      if (sendWallet == null) {
        throw Exception('Send wallet not found');
      }

      final isTestnet = sendWallet.network.isTestnet;
      final swapRepository =
          isTestnet ? _swapRepositoryTestnet : _swapRepository;

      final btcElectrumUrl =
          sendWallet.network.isTestnet
              ? ApiServiceConstants.bbElectrumTestUrl
              : ApiServiceConstants.bbElectrumUrl;

      final lbtcElectrumUrl =
          sendWallet.network.isTestnet
              ? ApiServiceConstants.publicElectrumTestUrl
              : ApiServiceConstants.bbLiquidElectrumUrlPath;

      switch (type) {
        case SwapType.bitcoinToLiquid:
          if (!sendWallet.network.isBitcoin) {
            throw Exception(
              'Send wallet must be a Bitcoin wallet for bitcoinToLiquid swap',
            );
          }
          return await swapRepository.createBitcoinToLiquidSwap(
            sendWalletId: sendWalletId,
            amountSat: amountSat,
            btcElectrumUrl: btcElectrumUrl,
            lbtcElectrumUrl: lbtcElectrumUrl,
            externalRecipientAddress: receiveAddress,
          );
        case SwapType.liquidToBitcoin:
          if (!sendWallet.network.isLiquid) {
            throw Exception(
              'Send wallet must be a Liquid wallet for liquidToBitcoin swap',
            );
          }
          return await swapRepository.createLiquidToBitcoinSwap(
            sendWalletId: sendWalletId,
            amountSat: amountSat,
            btcElectrumUrl: btcElectrumUrl,
            lbtcElectrumUrl: lbtcElectrumUrl,
            externalRecipientAddress: receiveAddress,
          );
        default:
          throw Exception(
            'Swap Type provided is not a supported chain swap to external address!',
          );
      }
    } catch (e) {
      throw Exception('Failed to create chain swap to external: $e');
    }
  }
}
