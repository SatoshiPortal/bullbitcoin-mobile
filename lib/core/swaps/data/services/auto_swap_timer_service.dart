import 'dart:async';

import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

const _autoSwapCheckInterval = Duration(minutes: 1);

enum AutoSwapStatus { started, swapExecuted, feeThresholdExceeded, error }

class AutoSwapEvent {
  final AutoSwapStatus status;
  final String? message;
  final Swap? swap;
  final double? currentFeePercent;

  AutoSwapEvent({
    required this.status,
    this.message,
    this.swap,
    this.currentFeePercent,
  });
}

class AutoSwapTimerService {
  final SwapRepository _swapRepository;
  final WalletRepository _walletRepository;
  final LiquidWalletRepository _liquidWalletRepository;
  final LiquidBlockchainRepository _liquidBlockchainRepository;
  final SeedRepository _seedRepository;
  final SettingsRepository _settingsRepository;

  Timer? _autoSwapTimer;
  final _autoSwapController = StreamController<AutoSwapEvent>.broadcast();
  bool _isStarted = false;

  Stream<AutoSwapEvent> get autoSwapEvents => _autoSwapController.stream;

  AutoSwapTimerService({
    required SwapRepository swapRepository,
    required WalletRepository walletRepository,
    required LiquidWalletRepository liquidWalletRepository,
    required LiquidBlockchainRepository liquidBlockchainRepository,
    required SeedRepository seedRepository,
    required SettingsRepository settingsRepository,
  }) : _swapRepository = swapRepository,
       _walletRepository = walletRepository,
       _liquidWalletRepository = liquidWalletRepository,
       _liquidBlockchainRepository = liquidBlockchainRepository,
       _seedRepository = seedRepository,
       _settingsRepository = settingsRepository;

  String _getTimestamp() {
    return DateFormat('HH:mm:ss').format(DateTime.now());
  }

  void startTimer() {
    if (_isStarted) {
      debugPrint(
        '[AutoSwap ${_getTimestamp()}] Timer already running, skipping initialization',
      );
      return;
    }

    debugPrint(
      '[AutoSwap ${_getTimestamp()}] Starting auto swap timer service',
    );

    _autoSwapTimer?.cancel();
    _isStarted = true;

    _autoSwapTimer = Timer.periodic(_autoSwapCheckInterval, (_) async {
      try {
        final settings = await _settingsRepository.fetch();
        final network = settings.environment.isTestnet ? 'testnet' : 'mainnet';
        debugPrint(
          '[AutoSwap ${_getTimestamp()}][$network] Running periodic check...',
        );
        await _checkAndExecuteAutoSwap();
      } catch (e) {
        final settings = await _settingsRepository.fetch();
        final network = settings.environment.isTestnet ? 'testnet' : 'mainnet';
        debugPrint(
          '[AutoSwap ${_getTimestamp()}][$network] Error during auto swap check: $e',
        );
        log.severe(
          '[AutoSwapTimerService][$network] Auto swap process failed: $e',
        );
        _autoSwapController.add(
          AutoSwapEvent(status: AutoSwapStatus.error, message: e.toString()),
        );
      }
    });

    _autoSwapController.add(AutoSwapEvent(status: AutoSwapStatus.started));
  }

  Future<void> _checkAndExecuteAutoSwap() async {
    final settings = await _settingsRepository.fetch();
    final network = settings.environment.isTestnet ? 'testnet' : 'mainnet';
    debugPrint(
      '[AutoSwap ${_getTimestamp()}][$network] Starting check and execute cycle',
    );

    final wallets = await _walletRepository.getWallets(
      onlyDefaults: true,
      environment: settings.environment,
    );

    final defaultLiquidWallet = wallets.where((w) => w.isLiquid).firstOrNull;
    final defaultBitcoinWallet = wallets.where((w) => !w.isLiquid).firstOrNull;

    if (defaultLiquidWallet == null || defaultBitcoinWallet == null) {
      debugPrint(
        '[AutoSwap ${_getTimestamp()}][$network] No default wallets found for ${settings.environment.name}',
      );
      return;
    }

    debugPrint(
      '[AutoSwap ${_getTimestamp()}][$network] Found default wallets - Liquid: ${defaultLiquidWallet.id}, Bitcoin: ${defaultBitcoinWallet.id}',
    );

    final autoSwapSettings = await _swapRepository.getAutoSwapParams(
      isTestnet: defaultLiquidWallet.isTestnet,
    );
    final walletBalance = defaultLiquidWallet.balanceSat.toInt();

    debugPrint(
      '[AutoSwap ${_getTimestamp()}][$network] Checking balance threshold - Current: $walletBalance sats',
    );
    if (!autoSwapSettings.passedRequiredBalance(walletBalance)) {
      debugPrint(
        '[AutoSwap ${_getTimestamp()}][$network] Balance threshold not exceeded',
      );
      return;
    }

    debugPrint(
      '[AutoSwap ${_getTimestamp()}][$network] Balance threshold exceeded, checking swap limits...',
    );
    final (swapLimits, swapFees) = await _swapRepository.getSwapLimitsAndFees(
      SwapType.liquidToBitcoin,
    );

    if (walletBalance < swapLimits.min || walletBalance > swapLimits.max) {
      debugPrint(
        '[AutoSwap ${_getTimestamp()}][$network] Balance outside swap limits (min: ${swapLimits.min}, max: ${swapLimits.max})',
      );
      return;
    }

    final totalFeePercent = swapFees.totalFeeAsPercentOfAmount(
      autoSwapSettings.swapAmount(walletBalance),
    );

    if (totalFeePercent > autoSwapSettings.feeThresholdPercent) {
      debugPrint(
        '[AutoSwap ${_getTimestamp()}][$network] Total fee percent ($totalFeePercent) is greater than or equal to fee threshold (${autoSwapSettings.feeThresholdPercent})',
      );
      _autoSwapController.add(
        AutoSwapEvent(
          status: AutoSwapStatus.feeThresholdExceeded,
          message: 'Fee threshold exceeded',
          currentFeePercent: totalFeePercent,
        ),
      );
      return;
    }

    debugPrint(
      '[AutoSwap ${_getTimestamp()}][$network] Balance within swap limits, preparing swap...',
    );

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
      '[AutoSwap ${_getTimestamp()}][$network] Creating swap with amount: ${autoSwapSettings.swapAmount(walletBalance)} sats',
    );
    final swap = await _swapRepository.createLiquidToBitcoinSwap(
      sendWalletMnemonic: liquidWalletMnemonic.mnemonicWords.join(' '),
      sendWalletId: defaultLiquidWallet.id,
      amountSat: autoSwapSettings.swapAmount(walletBalance),
      isTestnet: defaultLiquidWallet.isTestnet,
      btcElectrumUrl: btcElectrumUrl,
      lbtcElectrumUrl: lbtcElectrumUrl,
      receiveWalletId: defaultBitcoinWallet.id,
    );

    debugPrint('[AutoSwap ${_getTimestamp()}][$network] Building PSET...');
    final pset = await _liquidWalletRepository.buildPset(
      walletId: defaultLiquidWallet.id,
      address: swap.paymentAddress,
      amountSat: swap.paymentAmount,
      networkFee: const NetworkFee.relative(0.1),
    );

    debugPrint('[AutoSwap ${_getTimestamp()}][$network] Signing PSET...');
    final signedPset = await _liquidWalletRepository.signPset(
      walletId: defaultLiquidWallet.id,
      pset: pset,
    );

    debugPrint(
      '[AutoSwap ${_getTimestamp()}][$network] Broadcasting transaction...',
    );
    await _liquidBlockchainRepository.broadcastTransaction(
      signedPset: signedPset,
      isTestnet: settings.environment.isTestnet,
    );

    // Reset blockTillNextExecution after successful swap
    await _swapRepository.updateAutoSwapParams(
      autoSwapSettings.copyWith(blockTillNextExecution: false),
      isTestnet: settings.environment.isTestnet,
    );

    debugPrint(
      '[AutoSwap ${_getTimestamp()}][$network] Swap executed successfully!',
    );
    _autoSwapController.add(
      AutoSwapEvent(status: AutoSwapStatus.swapExecuted, swap: swap),
    );
    debugPrint(
      '[AutoSwap ${_getTimestamp()}][$network] Check and execute cycle completed',
    );
  }

  Future<void> dispose() async {
    debugPrint(
      '[AutoSwap ${_getTimestamp()}] Disposing auto swap timer service',
    );
    _autoSwapTimer?.cancel();
    _isStarted = false;
    await _autoSwapController.close();
  }
}
