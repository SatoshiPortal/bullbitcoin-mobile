import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/entities/swap.dart';
import 'package:bb_mobile/core/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/domain/services/wallet_repository_manager.dart';

class CreateReceiveSwapUseCase {
  final WalletRepositoryManager _walletRepositoryManager;
  final SwapRepository _swapRepository;
  final SwapRepository _swapRepositoryTestnet;

  CreateReceiveSwapUseCase({
    required WalletRepositoryManager walletRepositoryManager,
    required SwapRepository swapRepository,
    required SwapRepository swapRepositoryTestnet,
  })  : _walletRepositoryManager = walletRepositoryManager,
        _swapRepository = swapRepository,
        _swapRepositoryTestnet = swapRepositoryTestnet;

  Future<Swap> execute({
    required String walletId,
    required SwapType type,
    required BigInt amountSat,
  }) async {
    final walletRepository = _walletRepositoryManager.getRepository(walletId);

    if (walletRepository == null) {
      throw Exception('Wallet repository not found');
    }

    if (walletRepository.network.isLiquid &&
        type == SwapType.lightningToBitcoin) {
      throw Exception(
        'Cannot create a lightning to bitcoin with a liquid wallet',
      );
    }
    if (walletRepository.network.isBitcoin &&
        type == SwapType.lightningToLiquid) {
      throw Exception(
        'Cannot create a lightning to liquid swap with a bitcoin wallet',
      );
    }

    final environment = walletRepository.network.isTestnet
        ? Environment.testnet
        : Environment.mainnet;

    final swapRepository = environment == Environment.testnet
        ? _swapRepositoryTestnet
        : _swapRepository;

    final address = await walletRepository.getLastUnusedAddress();

    final swap = type == SwapType.lightningToLiquid
        ? await swapRepository.createLightningToLiquidSwap(
            liquidAddress: address.address,
            amountSat: amountSat,
            environment: environment,
          )
        : await swapRepository.createLightningToBitcoinSwap(
            bitcoinAddress: address.address,
            amountSat: amountSat,
            environment: environment,
          );

    return swap;
  }
}
