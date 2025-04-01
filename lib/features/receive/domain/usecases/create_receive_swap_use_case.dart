import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/services/wallet_manager_service.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_address_use_case.dart';

class CreateReceiveSwapUsecase {
  final WalletManagerService _walletManager;
  final SwapRepository _swapRepository;
  final SwapRepository _swapRepositoryTestnet;
  final SeedRepository _seedRepository;
  final GetReceiveAddressUsecase _getNewAddressUsecase;

  CreateReceiveSwapUsecase({
    required WalletManagerService walletManager,
    required SwapRepository swapRepository,
    required SwapRepository swapRepositoryTestnet,
    required SeedRepository seedRepository,
    required GetReceiveAddressUsecase getNewAddressUsecase,
  })  : _walletManager = walletManager,
        _swapRepository = swapRepository,
        _swapRepositoryTestnet = swapRepositoryTestnet,
        _seedRepository = seedRepository,
        _getNewAddressUsecase = getNewAddressUsecase;

  Future<LnReceiveSwap> execute({
    required String walletId,
    required SwapType type,
    required int amountSat,
    String? description,
  }) async {
    try {
      final wallet = await _walletManager.getWallet(walletId);
      if (wallet == null) {
        throw Exception('Wallet not found');
      }
      final swapRepository =
          wallet.network.isTestnet ? _swapRepositoryTestnet : _swapRepository;
      final limits = await _swapRepository.getSwapLimits(
        type: type,
      );
      if (amountSat < limits.min) {
        throw Exception(
          'Minimum Swap Amount: $limits.min sats',
        );
      }
      if (amountSat > limits.max) {
        throw Exception(
          'Maximum Swap Amount: $limits.max sats',
        );
      }

      final mnemonicSeed =
          await _seedRepository.get(wallet.masterFingerprint) as MnemonicSeed;
      final mnemonic = mnemonicSeed.mnemonicWords.join(' ');

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
          ? ApiServiceConstants.bbLiquidElectrumTestUrlPath
          : ApiServiceConstants.bbLiquidElectrumUrlPath;

      final claimAddress = await _getNewAddressUsecase.execute(
        walletId: walletId,
        newAddress: true,
      );

      switch (type) {
        case SwapType.lightningToBitcoin:
          return await swapRepository.createLightningToBitcoinSwap(
            walletId: walletId,
            amountSat: amountSat,
            isTestnet: wallet.network.isTestnet,
            mnemonic: mnemonic,
            electrumUrl: btcElectrumUrl,
            claimAddress: claimAddress.address,
            description: description,
          );

        case SwapType.lightningToLiquid:
          return await swapRepository.createLightningToLiquidSwap(
            walletId: walletId,
            amountSat: amountSat,
            isTestnet: wallet.network.isTestnet,
            mnemonic: mnemonic,
            electrumUrl: lbtcElectrumUrl,
            claimAddress: claimAddress.address,
            description: description,
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
