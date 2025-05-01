import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';

class CreateChainSwapUsecase {
  final WalletRepository _walletRepository;
  final SwapRepository _swapRepository;
  final SwapRepository _swapRepositoryTestnet;
  final SeedRepository _seedRepository;

  CreateChainSwapUsecase({
    required WalletRepository walletRepository,
    required SwapRepository swapRepository,
    required SwapRepository swapRepositoryTestnet,
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
      final bitcoinWallet = await _walletRepository.getWallet(bitcoinWalletId);
      final liquidWallet = await _walletRepository.getWallet(liquidWalletId);
      if (bitcoinWallet.network.isTestnet != liquidWallet.network.isTestnet) {
        throw Exception('Both wallets must be on the same network');
      }
      final isTestnet = bitcoinWallet.network.isTestnet;

      final swapRepository =
          isTestnet ? _swapRepositoryTestnet : _swapRepository;

      final bitcoinWalletMnemonic =
          await _seedRepository.get(bitcoinWallet.masterFingerprint)
              as MnemonicSeed;

      final liquidWalletMnemonic =
          await _seedRepository.get(liquidWallet.masterFingerprint)
              as MnemonicSeed;

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
          return await swapRepository.createBitcoinToLiquidSwap(
            sendWalletMnemonic: bitcoinWalletMnemonic.mnemonicWords.join(' '),
            sendWalletId: bitcoinWalletId,
            receiveWalletId: liquidWalletId,
            amountSat: amountSat!,
            isTestnet: isTestnet,
            btcElectrumUrl: btcElectrumUrl,
            lbtcElectrumUrl: lbtcElectrumUrl,
          );

        case SwapType.liquidToBitcoin:
          return await swapRepository.createLiquidToBitcoinSwap(
            sendWalletMnemonic: liquidWalletMnemonic.mnemonicWords.join(' '),
            sendWalletId: liquidWalletId,
            receiveWalletId: bitcoinWalletId,
            amountSat: amountSat!,
            isTestnet: isTestnet,
            btcElectrumUrl: btcElectrumUrl,
            lbtcElectrumUrl: lbtcElectrumUrl,
          );
        default:
          throw Exception('Swap Type provided is not a chain swap!');
      }
    } catch (e) {
      throw e.toString();
    }
  }
}
