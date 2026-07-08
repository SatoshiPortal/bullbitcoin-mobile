import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class CreateChainSwapToExternalUsecase {
  final WalletRepository _walletRepository;
  final BoltzSwapRepository _swapRepository;

  CreateChainSwapToExternalUsecase({
    required this._walletRepository,
    required this._swapRepository,
  });

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

      if (sendWallet.network.isTestnet) {
        throw Exception('Swaps are not supported on testnet');
      }

      final swapRepository = _swapRepository;

      final btcElectrumUrl = sendWallet.network.isTestnet
          ? ApiServiceConstants.publicElectrumTestUrl
          : ApiServiceConstants.bbElectrumUrl;

      final lbtcElectrumUrl = sendWallet.network.isTestnet
          ? ApiServiceConstants.publicliquidElectrumTestUrlPath
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
