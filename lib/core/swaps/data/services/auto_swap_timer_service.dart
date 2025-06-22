import 'dart:async';

import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';

const _autoSwapCheckInterval = Duration(minutes: 1);

enum AutoSwapStatus { started, swapExecuted, error }

class AutoSwapEvent {
  final AutoSwapStatus status;
  final String? message;
  final Swap? swap;

  AutoSwapEvent({required this.status, this.message, this.swap});
}

class AutoSwapTimerService {
  final SwapRepository _swapRepository;
  final WalletRepository _walletRepository;
  final LiquidWalletRepository _liquidWalletRepository;
  final LiquidBlockchainRepository _liquidBlockchainRepository;
  final SeedRepository _seedRepository;

  Timer? _autoSwapTimer;
  final _autoSwapController = StreamController<AutoSwapEvent>.broadcast();

  Stream<AutoSwapEvent> get autoSwapEvents => _autoSwapController.stream;

  AutoSwapTimerService({
    required SwapRepository swapRepository,
    required WalletRepository walletRepository,
    required LiquidWalletRepository liquidWalletRepository,
    required LiquidBlockchainRepository liquidBlockchainRepository,
    required SeedRepository seedRepository,
  }) : _swapRepository = swapRepository,
       _walletRepository = walletRepository,
       _liquidWalletRepository = liquidWalletRepository,
       _liquidBlockchainRepository = liquidBlockchainRepository,
       _seedRepository = seedRepository;

  void startTimer() {
    _autoSwapTimer?.cancel();
    _autoSwapTimer = Timer.periodic(_autoSwapCheckInterval, (_) async {
      try {
        await _checkAndExecuteAutoSwap();
      } catch (e) {
        log.severe('[AutoSwapTimerService] Auto swap process failed: $e');
        _autoSwapController.add(
          AutoSwapEvent(status: AutoSwapStatus.error, message: e.toString()),
        );
      }
    });
    _autoSwapController.add(AutoSwapEvent(status: AutoSwapStatus.started));
  }

  Future<void> _checkAndExecuteAutoSwap() async {
    final wallets = await _walletRepository.getWallets();

    final defaultLiquidWallet =
        wallets.where((w) => w.isDefault && w.isLiquid).firstOrNull;
    final defaultBitcoinWallet =
        wallets.where((w) => w.isDefault && !w.isLiquid).firstOrNull;

    if (defaultLiquidWallet == null || defaultBitcoinWallet == null) return;

    final autoSwapSettings = await _swapRepository.getAutoSwapParams();
    final walletBalance = defaultLiquidWallet.balanceSat.toInt();

    if (!autoSwapSettings.amountThresholdExceeded(walletBalance)) return;

    final (swapLimits, swapFees) = await _swapRepository.getSwapLimitsAndFees(
      SwapType.liquidToBitcoin,
    );

    if (walletBalance < swapLimits.min || walletBalance > swapLimits.max) {
      return;
    }

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

    final swap = await _swapRepository.createLiquidToBitcoinSwap(
      sendWalletMnemonic: liquidWalletMnemonic.mnemonicWords.join(' '),
      sendWalletId: defaultLiquidWallet.id,
      amountSat: autoSwapSettings.swapAmount(walletBalance),
      isTestnet: defaultLiquidWallet.isTestnet,
      btcElectrumUrl: btcElectrumUrl,
      lbtcElectrumUrl: lbtcElectrumUrl,
      receiveWalletId: defaultBitcoinWallet.id,
    );

    final swapFeePercent = swap.getFeeAsPercentOfAmount();
    if (!autoSwapSettings.withinFeeThreshold(swapFeePercent)) return;

    final pset = await _liquidWalletRepository.buildPset(
      walletId: defaultLiquidWallet.id,
      address: swap.paymentAddress,
      amountSat: swap.paymentAmount,
      networkFee: const NetworkFee.relative(0.1),
    );

    final signedPset = await _liquidWalletRepository.signPset(
      walletId: defaultLiquidWallet.id,
      pset: pset,
    );

    await _liquidBlockchainRepository.broadcastTransaction(
      signedPset: signedPset,
      isTestnet: defaultLiquidWallet.isTestnet,
    );

    _autoSwapController.add(
      AutoSwapEvent(status: AutoSwapStatus.swapExecuted, swap: swap),
    );
  }

  void dispose() {
    _autoSwapTimer?.cancel();
    _autoSwapController.close();
  }
}
