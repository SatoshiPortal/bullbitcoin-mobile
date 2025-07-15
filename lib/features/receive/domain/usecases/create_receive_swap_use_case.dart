import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/labels/domain/label.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_new_receive_address_use_case.dart';

class CreateReceiveSwapUsecase {
  final WalletRepository _walletRepository;
  final BoltzSwapRepository _swapRepository;
  final BoltzSwapRepository _swapRepositoryTestnet;
  final SeedRepository _seedRepository;
  final GetNewReceiveAddressUsecase _getNewAddressUsecase;
  final LabelRepository _labelRepository;

  CreateReceiveSwapUsecase({
    required WalletRepository walletRepository,
    required BoltzSwapRepository swapRepository,
    required BoltzSwapRepository swapRepositoryTestnet,
    required SeedRepository seedRepository,
    required GetNewReceiveAddressUsecase getNewAddressUsecase,
    required LabelRepository labelRepository,
  }) : _walletRepository = walletRepository,
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

      if (wallet == null) {
        throw Exception('Wallet not found');
      }

      final swapRepository =
          wallet.network.isTestnet ? _swapRepositoryTestnet : _swapRepository;
      final (limits, fees) = await _swapRepository.getSwapLimitsAndFees(type);
      if (amountSat < limits.min) {
        throw Exception('Minimum Swap Amount: $limits.min sats');
      }
      if (amountSat > limits.max) {
        throw Exception('Maximum Swap Amount: $limits.max sats');
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

      final btcElectrumUrl =
          wallet.network.isTestnet
              ? ApiServiceConstants.bbElectrumTestUrl
              : ApiServiceConstants.bbElectrumUrl;

      final lbtcElectrumUrl =
          wallet.network.isTestnet
              ? ApiServiceConstants.publicElectrumTestUrl
              : ApiServiceConstants.bbLiquidElectrumUrlPath;

      final claimAddress = await _getNewAddressUsecase.execute(
        walletId: walletId,
      );

      if (description != null && description.isNotEmpty) {
        final addressLabel = Label.addr(
          address: claimAddress.address,
          label: description,
          walletId: wallet.id,
        );
        await _labelRepository.store(addressLabel);
      }

      switch (type) {
        case SwapType.lightningToBitcoin:
          return await swapRepository.createLightningToBitcoinSwap(
            walletId: walletId,
            amountSat: amountSat,
            mnemonic: mnemonic,
            electrumUrl: btcElectrumUrl,
            claimAddress: claimAddress.address,
            description: description,
          );

        case SwapType.lightningToLiquid:
          return await swapRepository.createLightningToLiquidSwap(
            walletId: walletId,
            amountSat: amountSat,
            mnemonic: mnemonic,
            electrumUrl: lbtcElectrumUrl,
            claimAddress: claimAddress.address,
            description: description,
          );
        default:
          throw Exception('This is not a swap for the receive feature!');
      }
    } catch (e) {
      rethrow;
    }
  }
}
