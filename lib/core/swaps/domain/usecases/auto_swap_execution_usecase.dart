import 'package:bb_mobile/core/errors/autoswap_errors.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/labels/domain/label.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/ports/blockchain_port.dart';
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
  final BlockchainPort _blockchainPort;
  final WalletTransactionRepository _walletTxRepository;
  final LabelRepository _labelRepository;

  AutoSwapExecutionUsecase({
    required BoltzSwapRepository mainnetRepository,
    required BoltzSwapRepository testnetRepository,
    required WalletRepository walletRepository,
    required LiquidWalletRepository liquidWalletRepository,
    required BlockchainPort blockchainPort,
    required WalletTransactionRepository walletTxRepository,
    required LabelRepository labelRepository,
  }) : _mainnetRepository = mainnetRepository,
       _testnetRepository = testnetRepository,
       _walletRepository = walletRepository,
       _liquidWalletRepository = liquidWalletRepository,
       _blockchainPort = blockchainPort,
       _walletTxRepository = walletTxRepository,
       _labelRepository = labelRepository;

  Future<Swap> execute({
    required bool isTestnet,
    required bool feeBlock,
  }) async {
    final swapRepository = isTestnet ? _testnetRepository : _mainnetRepository;
    final autoSwapSettings = await swapRepository.getAutoSwapParams();
    // check if recipient wallet id is set

    if (!autoSwapSettings.enabled || autoSwapSettings.showWarning) {
      throw AutoSwapDisabledException(
        'Auto swap is disabled/warning not disabled yet.',
      );
    }
    final environment = isTestnet ? Environment.testnet : Environment.mainnet;
    final wallets = await _walletRepository.getWallets(
      environment: environment,
    );
    final defaultBitcoinWallet = wallets
        .where((w) => w.isDefault && !w.isLiquid)
        .firstOrNull;
    final defaultLiquidWallet = wallets
        .where((w) => w.isDefault && w.isLiquid)
        .firstOrNull;

    if (defaultLiquidWallet == null || defaultBitcoinWallet == null) {
      throw Exception('No default wallets found');
    }

    if (autoSwapSettings.recipientWalletId == null) {
      final updatedSwapSettings = autoSwapSettings.copyWith(
        recipientWalletId: defaultBitcoinWallet.id,
      );
      await swapRepository.updateAutoSwapParams(updatedSwapSettings);
    }

    final sendBitcoinWallet = autoSwapSettings.recipientWalletId != null
        ? wallets
              .where((w) => w.id == autoSwapSettings.recipientWalletId)
              .firstOrNull
        : defaultBitcoinWallet;

    if (sendBitcoinWallet == null) {
      // if user deleted the bitcoin wallet, this could be null
      // TODO: when a set autoswap wallet is deleted, we should prompt the user to update the autoswap settings
      throw Exception(
        'Send bitcoin wallet not found. Check autoswap settings.',
      );
    }
    debugPrint('Found default wallet - Liquid: ${defaultLiquidWallet.id}');

    final walletBalance = defaultLiquidWallet.balanceSat.toInt();

    debugPrint('Checking balance threshold - Current: $walletBalance sats');
    if (!autoSwapSettings.passedRequiredBalance(walletBalance)) {
      throw BalanceThresholdException(
        currentBalance: walletBalance,
        requiredBalance: autoSwapSettings.triggerBalanceSats,
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

    final btcElectrumUrl =
        defaultBitcoinWallet.isTestnet
            ? ApiServiceConstants.bbElectrumTestUrl
            : ApiServiceConstants.bbElectrumUrl;

    final lbtcElectrumUrl = defaultLiquidWallet.isTestnet
        ? ApiServiceConstants.publicElectrumTestUrl
        : ApiServiceConstants.bbLiquidElectrumUrlPath;

    debugPrint(
      'Creating swap with amount: ${autoSwapSettings.swapAmount(walletBalance)} sats',
    );
    final swap = await swapRepository.createLiquidToBitcoinSwap(
      sendWalletId: defaultLiquidWallet.id,
      amountSat: autoSwapSettings.swapAmount(walletBalance),
      btcElectrumUrl: btcElectrumUrl,
      lbtcElectrumUrl: lbtcElectrumUrl,
      receiveWalletId: sendBitcoinWallet.id,
    );

    debugPrint('Building PSET...');
    final pset = await _liquidWalletRepository.buildPset(
      walletId: defaultLiquidWallet.id,
      address: swap.paymentAddress,
      amountSat: swap.paymentAmount,
      networkFee: const NetworkFee.relative(0.1),
    );

    debugPrint('Getting absolute fees from PSET...');
    final (_, absoluteFees) = await _liquidWalletRepository
        .getPsetSizeAndAbsoluteFees(pset: pset);

    debugPrint('Signing PSET...');
    final signedPset = await _liquidWalletRepository.signPset(
      walletId: defaultLiquidWallet.id,
      pset: pset,
    );

    debugPrint('Broadcasting transaction...');
    final txid = await _blockchainPort.broadcastLiquidTransaction(
      signedPset: signedPset,
      isTestnet: defaultLiquidWallet.isTestnet,
    );

    await swapRepository.updatePaidSendSwap(
      swapId: swap.id,
      txid: txid,
      absoluteFees: absoluteFees,
    );
    // Reset blockTillNextExecution after successful swap
    await swapRepository.updateAutoSwapParams(
      autoSwapSettings.copyWith(blockTillNextExecution: false),
    );
    debugPrint('Swap executed successfully!');
    // sometimes sync fails and label is not set
    final txLabel = Label.tx(
      transactionId: txid,
      origin: defaultLiquidWallet.id,
      label: 'Auto-Swap',
    );
    await _labelRepository.store(txLabel);

    // sync at the end to ensure label is set
    await _walletTxRepository.getWalletTransaction(
      txid,
      walletId: defaultLiquidWallet.id,
      sync: true,
    );
    return swap;
  }
}
