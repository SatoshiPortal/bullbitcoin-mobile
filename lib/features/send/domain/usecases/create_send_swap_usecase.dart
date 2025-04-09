// TODO: ?
// TODO: string invoice, walletId and return LnSendSwap

import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
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

  Future<Swap> execute({
    required String walletId,
    required SwapType type,
    required int amountSat,
    required String invoice,
  }) async {
    try {
      final wallet = await _walletRepository.getWallet(walletId);

      final swapRepository =
          wallet.network.isTestnet ? _swapRepositoryTestnet : _swapRepository;
      final limits = await _swapRepository.getSwapLimits(type: type);
      if (amountSat < limits.min) {
        throw Exception('Minimum Swap Amount: $limits.min sats');
      }
      if (amountSat > limits.max) {
        throw Exception('Maximum Swap Amount: $limits.max sats');
      }

      final mnemonic = await _seedRepository.get(wallet.masterFingerprint);

      if (wallet.network.isLiquid && type == SwapType.lightningToBitcoin) {
        throw Exception(
          'Cannot create a lightning to bitcoin with a liquid wallet',
        );
      }
      if (wallet.network.isBitcoin && type == SwapType.lightningToLiquid) {
        throw Exception(
          'Cannot create a lightning to liquid swap with a bitcoin wallet',
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
            walletId: walletId,
            invoice: invoice,
            isTestnet: wallet.network.isTestnet,
            mnemonic: mnemonic.toString(),
            electrumUrl: btcElectrumUrl,
          );

        case SwapType.liquidToLightning:
          return await swapRepository.createLiquidToLightningSwap(
            walletId: walletId,
            invoice: invoice,
            isTestnet: wallet.network.isTestnet,
            mnemonic: mnemonic.toString(),
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
