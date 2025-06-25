import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:bb_mobile/core/errors/autoswap_errors.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:flutter/foundation.dart';

class AutoSwapExecutionUsecase {
  final SwapRepository _mainnetRepository;
  final SwapRepository _testnetRepository;
  final WalletRepository _walletRepository;
  final LiquidWalletRepository _liquidWalletRepository;
  final LiquidBlockchainRepository _liquidBlockchainRepository;
  final SeedRepository _seedRepository;

  AutoSwapExecutionUsecase({
    required SwapRepository mainnetRepository,
    required SwapRepository testnetRepository,
    required WalletRepository walletRepository,
    required LiquidWalletRepository liquidWalletRepository,
    required LiquidBlockchainRepository liquidBlockchainRepository,
    required SeedRepository seedRepository,
  }) : _mainnetRepository = mainnetRepository,
       _testnetRepository = testnetRepository,
       _walletRepository = walletRepository,
       _liquidWalletRepository = liquidWalletRepository,
       _liquidBlockchainRepository = liquidBlockchainRepository,
       _seedRepository = seedRepository;

  Future<Swap> execute({
    required bool isTestnet,
    required bool feeBlock,
  }) async {
    final wallets = await _walletRepository.getWallets();

    final defaultLiquidWallet =
        wallets.where((w) => w.isDefault && w.isLiquid).firstOrNull;
    final defaultBitcoinWallet =
        wallets.where((w) => w.isDefault && !w.isLiquid).firstOrNull;

    if (defaultLiquidWallet == null || defaultBitcoinWallet == null) {
      throw Exception('No default wallets found');
    }

    debugPrint(
      'Found default wallets - Liquid: ${defaultLiquidWallet.id}, Bitcoin: ${defaultBitcoinWallet.id}',
    );

    final repository = isTestnet ? _testnetRepository : _mainnetRepository;
    final autoSwapSettings = await repository.getAutoSwapParams(
      isTestnet: isTestnet,
    );
    final walletBalance = defaultLiquidWallet.balanceSat.toInt();

    debugPrint('Checking balance threshold - Current: $walletBalance sats');
    if (!autoSwapSettings.passedRequiredBalance(walletBalance)) {
      throw BalanceThresholdException(
        currentBalance: walletBalance,
        requiredBalance: autoSwapSettings.balanceThresholdSats * 2,
      );
    }

    debugPrint('Balance threshold exceeded, checking swap limits...');
    final (swapLimits, swapFees) = await repository.getSwapLimitsAndFees(
      SwapType.liquidToBitcoin,
    );

    if (walletBalance < swapLimits.min || walletBalance > swapLimits.max) {
      throw Exception(
        'Balance outside swap limits (min: ${swapLimits.min}, max: ${swapLimits.max})',
      );
    }

    if (feeBlock) {
      final totalFeePercent = swapFees.totalFeeAsPercentOfAmount(
        autoSwapSettings.swapAmount(walletBalance),
      );

      if (totalFeePercent > autoSwapSettings.feeThresholdPercent) {
        throw FeeBlockException(
          currentFeePercent: totalFeePercent,
          thresholdPercent: autoSwapSettings.feeThresholdPercent.toDouble(),
        );
      }
    }

    debugPrint('Balance within swap limits, preparing swap...');

    final liquidWalletMnemonic =
        await _seedRepository.get(defaultLiquidWallet.masterFingerprint)
            as MnemonicSeed;

    final btcElectrumUrl =
        defaultBitcoinWallet.isTestnet
            ? ApiServiceConstants.bbElectrumTestUrl
            : ApiServiceConstants.bbElectrumUrl;

    final lbtcElectrumUrl =
        defaultLiquidWallet.isTestnet
            ? ApiServiceConstants.publicElectrumTestUrl
            : ApiServiceConstants.bbLiquidElectrumUrlPath;

    debugPrint(
      'Creating swap with amount: ${autoSwapSettings.swapAmount(walletBalance)} sats',
    );
    final swap = await repository.createLiquidToBitcoinSwap(
      sendWalletMnemonic: liquidWalletMnemonic.mnemonicWords.join(' '),
      sendWalletId: defaultLiquidWallet.id,
      amountSat: autoSwapSettings.swapAmount(walletBalance),
      isTestnet: defaultLiquidWallet.isTestnet,
      btcElectrumUrl: btcElectrumUrl,
      lbtcElectrumUrl: lbtcElectrumUrl,
      receiveWalletId: defaultBitcoinWallet.id,
    );

    debugPrint('Building PSET...');
    final pset = await _liquidWalletRepository.buildPset(
      walletId: defaultLiquidWallet.id,
      address: swap.paymentAddress,
      amountSat: swap.paymentAmount,
      networkFee: const NetworkFee.relative(0.1),
    );

    debugPrint('Signing PSET...');
    final signedPset = await _liquidWalletRepository.signPset(
      walletId: defaultLiquidWallet.id,
      pset: pset,
    );

    debugPrint('Broadcasting transaction...');
    await _liquidBlockchainRepository.broadcastTransaction(
      signedPset: signedPset,
      isTestnet: defaultLiquidWallet.isTestnet,
    );

    // Reset blockTillNextExecution after successful swap
    await repository.updateAutoSwapParams(
      autoSwapSettings.copyWith(blockTillNextExecution: false),
      isTestnet: isTestnet,
    );

    debugPrint('Swap executed successfully!');
    return swap;
  }
}
