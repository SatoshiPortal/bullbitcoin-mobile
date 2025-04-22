import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/entity/address.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_use_case.dart';

class CreateReceiveSwapUsecase {
  final WalletRepository _walletRepository;
  final SwapRepository _swapRepository;
  final SwapRepository _swapRepositoryTestnet;
  final SeedRepository _seedRepository;
  final GetReceiveAddressUsecase _getNewAddressUsecase;
  final LabelRepository _labelRepository;

  CreateReceiveSwapUsecase({
    required WalletRepository walletRepository,
    required SwapRepository swapRepository,
    required SwapRepository swapRepositoryTestnet,
    required SeedRepository seedRepository,
    required GetReceiveAddressUsecase getNewAddressUsecase,
    required LabelRepository labelRepository,
  })  : _walletRepository = walletRepository,
        _swapRepository = swapRepository,
        _swapRepositoryTestnet = swapRepositoryTestnet,
        _seedRepository = seedRepository,
        _getNewAddressUsecase = getNewAddressUsecase,
        _labelRepository = labelRepository;

  Future<LnReceiveSwap> execute({
    required String walletId,
    required SwapType type,
    required int amountSat,
    String? description,
  }) async {
    try {
      final wallet = await _walletRepository.getWallet(walletId);

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
          ? ApiServiceConstants.publicElectrumTestUrl
          : ApiServiceConstants.bbLiquidElectrumUrlPath;

      final claimAddress = await _getNewAddressUsecase.execute(
        walletId: walletId,
        newAddress: true,
      );

      if (description != null || description!.isNotEmpty) {
        await _labelRepository.store<Address>(
          entity: claimAddress,
          label: description,
          origin: wallet.origin,
        );
      }

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
