import 'dart:math';

import 'package:bb_mobile/_pkg/consts/config.dart';
import 'package:bb_mobile/core/data/datasources/key_value_storage/key_value_storage_data_source.dart';
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
    try {
      final walletRepository = _walletRepositoryManager.getRepository(walletId);
      if (walletRepository == null) {
        throw Exception('Wallet repository not found');
      }
      final mnemonic = await _seedRepository.getSeed(walletRepository.id);

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

      final nextWalletIndex = await _swapRepository.getNextBestIndex(walletId);

      switch (type) {
        case SwapType.lightningToBitcoin:
          return swapRepository.createLightningToBitcoinSwap(
            walletId: walletId,
            amountSat: amountSat,
            environment: environment,
            mnemonic: mnemonic.toString(),
            index: nextWalletIndex,
            electrumUrl: bbElectrumMain,
          );

        case SwapType.lightningToLiquid:
          return swapRepository.createLightningToLiquidSwap(
            walletId: walletId,
            amountSat: amountSat,
            environment: environment,
            mnemonic: mnemonic.toString(),
            index: nextWalletIndex,
            electrumUrl: liquidElectrumTestUrl,
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
