import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:bb_mobile/core/errors/autoswap_errors.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/labels/domain/label.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:flutter/foundation.dart';

class AutoSwapExecutionUsecase {
  final BoltzSwapRepository _mainnetRepository;
  final BoltzSwapRepository _testnetRepository;
  final WalletRepository _walletRepository;
  final LiquidWalletRepository _liquidWalletRepository;
  final LiquidBlockchainRepository _liquidBlockchainRepository;
  final SeedRepository _seedRepository;
  final WalletTransactionRepository _walletTxRepository;
  final LabelRepository _labelRepository;

  AutoSwapExecutionUsecase({
    required BoltzSwapRepository mainnetRepository,
    required BoltzSwapRepository testnetRepository,
    required WalletRepository walletRepository,
    required LiquidWalletRepository liquidWalletRepository,
    required LiquidBlockchainRepository liquidBlockchainRepository,
    required SeedRepository seedRepository,
    required WalletTransactionRepository walletTxRepository,
    required LabelRepository labelRepository,
  }) : _mainnetRepository = mainnetRepository,
       _testnetRepository = testnetRepository,
       _walletRepository = walletRepository,
       _liquidWalletRepository = liquidWalletRepository,
       _liquidBlockchainRepository = liquidBlockchainRepository,
       _seedRepository = seedRepository,
       _walletTxRepository = walletTxRepository,
       _labelRepository = labelRepository;

  Future<Swap> execute({
    required bool isTestnet,
    required bool feeBlock,
  }) async {
    final swapRepository = isTestnet ? _testnetRepository : _mainnetRepository;
    final autoSwapSettings = await swapRepository.getAutoSwapParams();
    if (!autoSwapSettings.enabled) {
      throw AutoSwapDisabledException('Auto swap is disabled');
    }
    final environment = isTestnet ? Environment.testnet : Environment.mainnet;
    final wallets = await _walletRepository.getWallets(
      environment: environment,
    );

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

    final walletBalance = defaultLiquidWallet.balanceSat.toInt();

    debugPrint('Checking balance threshold - Current: $walletBalance sats');
    if (!autoSwapSettings.passedRequiredBalance(walletBalance)) {
      throw BalanceThresholdException(
        currentBalance: walletBalance,
        requiredBalance: autoSwapSettings.balanceThresholdSats * 2,
      );
    }

    debugPrint('Balance threshold exceeded, checking swap limits...');
    final (swapLimits, swapFees) = await swapRepository.getSwapLimitsAndFees(
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
          thresholdPercent: autoSwapSettings.feeThresholdPercent,
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
    final swap = await swapRepository.createLiquidToBitcoinSwap(
      sendWalletMnemonic: liquidWalletMnemonic.mnemonicWords.join(' '),
      sendWalletId: defaultLiquidWallet.id,
      amountSat: autoSwapSettings.swapAmount(walletBalance),
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
    final txid = await _liquidBlockchainRepository.broadcastTransaction(
      signedPset: signedPset,
      isTestnet: defaultLiquidWallet.isTestnet,
    );

    await swapRepository.updatePaidSendSwap(
      swapId: swap.id,
      txid: txid,
      absoluteFees: 0,
    );
    // Reset blockTillNextExecution after successful swap
    await swapRepository.updateAutoSwapParams(
      autoSwapSettings.copyWith(blockTillNextExecution: false),
    );
    debugPrint('Swap executed successfully!');

    final walletTx = await _walletTxRepository.getWalletTransaction(
      txid,
      walletId: defaultLiquidWallet.id,
      sync: true,
    );

    if (walletTx != null) {
      final txLabel = Label.tx(
        transactionId: walletTx.txId,
        walletId: defaultLiquidWallet.id,
        label: 'Auto-Swap',
      );
      await _labelRepository.store(txLabel);
    }
    return swap;
  }
}
