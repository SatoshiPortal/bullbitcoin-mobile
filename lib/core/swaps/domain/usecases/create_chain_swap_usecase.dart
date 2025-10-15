import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class CreateChainSwapUsecase {
  final WalletRepository _walletRepository;
  final BoltzSwapRepository _swapRepository;
  final BoltzSwapRepository _swapRepositoryTestnet;
  final SeedRepository _seedRepository;

  CreateChainSwapUsecase({
    required WalletRepository walletRepository,
    required BoltzSwapRepository swapRepository,
    required BoltzSwapRepository swapRepositoryTestnet,
    required SeedRepository seedRepository,
  }) : _walletRepository = walletRepository,
       _swapRepository = swapRepository,
       _swapRepositoryTestnet = swapRepositoryTestnet,
       _seedRepository = seedRepository;

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

      if (bitcoinWallet.network.isTestnet != liquidWallet.network.isTestnet) {
        throw Exception('Both wallets must be on the same network');
      }

      if (bitcoinWallet.isWatchOnly && type == SwapType.bitcoinToLiquid) {
        throw Exception(
          'Cannot create Bitcoin To Liquid swap with watch-only bitcoin wallet',
        );
      }

      final isTestnet = bitcoinWallet.network.isTestnet;
      final swapRepository =
          isTestnet ? _swapRepositoryTestnet : _swapRepository;

      final btcElectrumUrl =
          bitcoinWallet.network.isTestnet
              ? ApiServiceConstants.bbElectrumTestUrl
              : ApiServiceConstants.bbElectrumUrl;

      final lbtcElectrumUrl =
          liquidWallet.network.isTestnet
              ? ApiServiceConstants.publicElectrumTestUrl
              : ApiServiceConstants.bbLiquidElectrumUrlPath;

      switch (type) {
        case SwapType.bitcoinToLiquid:
          final bitcoinMnemonicSeed = await _seedRepository.get(
            bitcoinWallet.masterFingerprint,
          );
          if (bitcoinMnemonicSeed is! MnemonicSeed) {
            throw Exception('Bitcoin wallet seed not found');
          }

          return await swapRepository.createBitcoinToLiquidSwap(
            sendWalletMnemonic: bitcoinMnemonicSeed.mnemonicWords.join(' '),
            sendWalletId: bitcoinWalletId,
            receiveWalletId: liquidWalletId,
            amountSat: amountSat!,
            btcElectrumUrl: btcElectrumUrl,
            lbtcElectrumUrl: lbtcElectrumUrl,
          );
        case SwapType.liquidToBitcoin:
          final liquidMnemonicSeed = await _seedRepository.get(
            liquidWallet.masterFingerprint,
          );
          if (liquidMnemonicSeed is! MnemonicSeed) {
            throw Exception('Liquid wallet seed not found');
          }

          return await swapRepository.createLiquidToBitcoinSwap(
            sendWalletMnemonic: liquidMnemonicSeed.mnemonicWords.join(' '),
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
