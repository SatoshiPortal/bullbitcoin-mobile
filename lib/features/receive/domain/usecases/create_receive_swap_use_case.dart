import 'package:bb_mobile/core/data/repositories/seed_repository_impl.dart';
import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/entities/swap.dart';
import 'package:bb_mobile/core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/domain/services/wallet_repository_manager.dart';

class CreateReceiveSwapUseCase {
  final WalletRepositoryManager _walletRepositoryManager;
  final SwapRepository _swapRepository;
  final SwapRepository _swapRepositoryTestnet;
  final SeedRepository _seedRepository;

  CreateReceiveSwapUseCase({
    required WalletRepositoryManager walletRepositoryManager,
    required SwapRepository swapRepository,
    required SwapRepository swapRepositoryTestnet,
    required SeedRepository seedRepository,
  })  : _walletRepositoryManager = walletRepositoryManager,
        _swapRepository = swapRepository,
        _swapRepositoryTestnet = swapRepositoryTestnet,
        _seedRepository = seedRepository;

  Future<Swap> execute({
    required String walletId,
    required SwapType type,
    required BigInt amountSat,
  }) async {
    final walletRepository = _walletRepositoryManager.getRepository(walletId);
    // TODO: discuss error handling
    if (walletRepository == null) {
      throw Exception('Wallet repository not found');
    }
    final mnemonic = await _seedRepository.getSeed(walletRepository.id);
    // TODO: what if a walletId does not have a seed; for example xpub wallet
    if (mnemonic == null) {
      throw Exception('Mnemonic for wallet not found');
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

    // TODO read all swaps from the database and increment index
    final index = BigInt.from(0);
    // final address = await walletRepository.getLastUnusedAddress();

    final swap = type == SwapType.lightningToLiquid
        ? await swapRepository.createLightningToLiquidSwap(
            walletId: walletId,
            amountSat: amountSat,
            environment: environment,
            mnemonic: mnemonic.toString(),
            index: index,
            electrumUrl: '',
          )
        : await swapRepository.createLightningToBitcoinSwap(
            walletId: walletId,
            amountSat: amountSat,
            environment: environment,
            mnemonic: mnemonic.toString(),
            index: index,
            electrumUrl: '',
          );

    return swap;
  }
}
