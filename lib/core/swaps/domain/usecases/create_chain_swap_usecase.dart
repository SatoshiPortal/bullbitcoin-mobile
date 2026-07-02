import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class CreateChainSwapUsecase {
  final WalletRepository _walletRepository;
  final BoltzSwapRepository _swapRepository;

  CreateChainSwapUsecase({
    required this._walletRepository,
    required this._swapRepository,
  });

  Future<ChainSwap> execute({
    required String bitcoinWalletId,
    required String liquidWalletId,
    required SwapType type,
    bool drain = false,
    int? amountSat,
  }) async {
    try {
      final (bitcoinWallet, liquidWallet) =
          await (
            _walletRepository.getWallet(bitcoinWalletId),
            _walletRepository.getWallet(liquidWalletId),
          ).wait;

      if (bitcoinWallet == null || liquidWallet == null) {
        throw Exception('One or both wallets not found');
      }

      if (bitcoinWallet.network.isTestnet || liquidWallet.network.isTestnet) {
        throw Exception('Swaps are not supported on testnet');
      }

      if (bitcoinWallet.network.isTestnet != liquidWallet.network.isTestnet) {
        throw Exception('Both wallets must be on the same network');
      }

      if (bitcoinWallet.isWatchOnly && type == SwapType.bitcoinToLiquid) {
        throw Exception(
          'Cannot create Bitcoin To Liquid swap with watch-only bitcoin wallet',
        );
      }

      final swapRepository = _swapRepository;

      final btcElectrumUrl =
          bitcoinWallet.network.isTestnet
              ? ApiServiceConstants.publicElectrumTestUrl
              : ApiServiceConstants.bbElectrumUrl;

      final lbtcElectrumUrl =
          liquidWallet.network.isTestnet
              ? ApiServiceConstants.publicliquidElectrumTestUrlPath
              : ApiServiceConstants.bbLiquidElectrumUrlPath;

      switch (type) {
        case SwapType.bitcoinToLiquid:
          return await swapRepository.createBitcoinToLiquidSwap(
            sendWalletId: bitcoinWalletId,
            receiveWalletId: liquidWalletId,
            amountSat: amountSat!,
            btcElectrumUrl: btcElectrumUrl,
            lbtcElectrumUrl: lbtcElectrumUrl,
          );
        case SwapType.liquidToBitcoin:
          return await swapRepository.createLiquidToBitcoinSwap(
            sendWalletId: liquidWalletId,
            receiveWalletId: bitcoinWalletId,
            amountSat: amountSat!,
            btcElectrumUrl: btcElectrumUrl,
            lbtcElectrumUrl: lbtcElectrumUrl,
          );
        default:
          throw Exception('Swap Type provided is not a chain swap!');
      }
    } catch (e) {
      throw Exception('Failed to create chain swap: $e');
    }
  }
}
