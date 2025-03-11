import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/swap.dart';
import 'package:bb_mobile/_core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';
import 'package:bb_mobile/_utils/constants.dart';

class CreateReceiveSwapUseCase {
  final WalletManagerService _walletManager;
  final SwapRepository _swapRepository;
  final SwapRepository _swapRepositoryTestnet;
  final SeedRepository _seedRepository;

  CreateReceiveSwapUseCase({
    required WalletManagerService walletManager,
    required SwapRepository swapRepository,
    required SwapRepository swapRepositoryTestnet,
    required SeedRepository seedRepository,
  })  : _walletManager = walletManager,
        _swapRepository = swapRepository,
        _swapRepositoryTestnet = swapRepositoryTestnet,
        _seedRepository = seedRepository;

  Future<Swap> execute({
    required String walletId,
    required SwapType type,
    required BigInt amountSat,
  }) async {
    try {
      final wallet = await _walletManager.getWallet(walletId);
      if (wallet == null) {
        throw Exception('Wallet not found');
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

      final environment =
          wallet.network.isTestnet ? Environment.testnet : Environment.mainnet;

      final swapRepository =
          wallet.network.isTestnet ? _swapRepositoryTestnet : _swapRepository;

      switch (type) {
        case SwapType.lightningToBitcoin:
          return swapRepository.createLightningToBitcoinSwap(
            walletId: walletId,
            amountSat: amountSat,
            environment: environment,
            mnemonic: mnemonic.toString(),
            electrumUrl: ApiServiceConstants
                .bbElectrumUrl, // TODO: check if this should be test or mainnet following the environment
          );

        case SwapType.lightningToLiquid:
          return swapRepository.createLightningToLiquidSwap(
            walletId: walletId,
            amountSat: amountSat,
            environment: environment,
            mnemonic: mnemonic.toString(),
            electrumUrl: ApiServiceConstants
                .publicliquidElectrumTestUrlPath, // TODO: check if this should be test or mainnet following the environment
          );
        default:
          throw Exception(
            'This is not a swap for the receive feature!',
          );
      }
    } catch (e) {
      rethrow;
    }
  }
}
