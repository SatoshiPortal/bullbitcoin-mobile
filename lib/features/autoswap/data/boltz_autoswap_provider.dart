import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:swaps/swaps.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/wallet/data/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_provider_port.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bull_logger/bull_logger.dart';

class BoltzAutoswapProvider implements AutoswapProviderPort {
  final GetSwapsUsecase _getSwaps;
  final GetSwapLimitsAndFeesUsecase _getSwapLimitsAndFees;
  final CreateChainSwapUsecase _createChainSwap;
  final RecordSwapLockupUsecase _recordSwapLockup;
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;
  final LiquidWalletRepository _liquidWalletRepository;
  final GetReceiveAddressUsecase _getReceiveAddress;
  final BroadcastLiquidTransactionUsecase _broadcastLiquidTransaction;
  final LabelsFacade _labelsFacade;

  const BoltzAutoswapProvider(
    this._getSwaps,
    this._getSwapLimitsAndFees,
    this._createChainSwap,
    this._recordSwapLockup,
    this._walletRepository,
    this._settingsRepository,
    this._liquidWalletRepository,
    this._getReceiveAddress,
    this._broadcastLiquidTransaction,
    this._labelsFacade,
  );

  @override
  Future<Result<String, AutoswapFailure>> execute(AutoSwap settings) async {
    try {
      final environment = (await _settingsRepository.fetch()).environment;
      final List<Wallet> wallets;
      switch (await _walletRepository.getWallets(environment: environment)) {
        case Ok(:final value):
          wallets = value;
        case Err(:final failure):
          return Err(
            AutoswapProviderFailure('wallets: ${failure.runtimeType}'),
          );
      }
      final liquidWallet = wallets
          .where((wallet) => wallet.isDefault && wallet.isLiquid)
          .firstOrNull;
      final recipientWallet = wallets
          .where((wallet) => wallet.id == settings.recipientWalletId)
          .firstOrNull;
      if (liquidWallet == null ||
          recipientWallet == null ||
          !recipientWallet.isBitcoin) {
        return const Err(AutoswapNoWalletFailure());
      }
      if (liquidWallet.isHardwareWallet) {
        return const Err(AutoswapUnsupportedWalletFailure());
      }

      final existing = (await _getSwaps.execute(walletId: liquidWallet.id))
          .whereType<ChainSwap>()
          .where(
            (swap) =>
                swap.type == SwapType.liquidToBitcoin &&
                swap.sendWalletId == liquidWallet.id &&
                !swap.status.isTerminal,
          )
          .firstOrNull;
      if (existing != null) {
        return existing.sendTxid == null
            ? const Err(AutoswapPendingFailure())
            : Ok(existing.id);
      }

      final balanceSat = liquidWallet.balanceSat?.toInt();
      if (balanceSat == null) {
        return const Err(AutoswapExecutionFailure('Wallet unavailable'));
      }
      if (!settings.passedRequiredBalance(balanceSat)) {
        return Err(
          AutoswapInsufficientBalanceFailure(
            currentBalanceSats: balanceSat,
            requiredThresholdSats: settings.triggerBalanceSats,
          ),
        );
      }
      final fallback = await _getReceiveAddress.execute(
        walletId: liquidWallet.id,
      );
      final feeResult = await _estimateNetworkFee(
        walletId: liquidWallet.id,
        address: fallback.address,
        amountSat: balanceSat - settings.balanceThresholdSats,
      );
      final int networkFeeSat;
      switch (feeResult) {
        case Ok(:final value):
          networkFeeSat = value;
        case Err(:final failure):
          return Err(failure);
      }
      final amountSat =
          balanceSat - settings.balanceThresholdSats - networkFeeSat;
      if (amountSat <= 0) {
        return const Err(AutoswapInsufficientBalanceFailure());
      }

      final SwapLimits limits;
      final SwapFees providerFees;
      switch (await _getSwapLimitsAndFees.execute(SwapType.liquidToBitcoin)) {
        case Ok(:final value):
          (limits, providerFees) = value;
        case Err(:final failure):
          return Err(_creationFailure(failure));
      }
      if (!limits.accepts(amountSat)) {
        return const Err(AutoswapAmountOutOfBoundsFailure());
      }
      final totalFeePercent =
          providerFees.totalFeeAsPercentOfAmount(amountSat) +
          (networkFeeSat / amountSat * 100);
      if (!settings.withinFeeThreshold(totalFeePercent)) {
        return Err(
          AutoswapFeeLimitExceededFailure(
            feePercent: totalFeePercent,
            thresholdPercent: settings.feeThresholdPercent,
          ),
        );
      }

      final ChainSwap swap;
      switch (await _createChainSwap.execute(
        sendWalletId: liquidWallet.id,
        amountSat: amountSat,
        fromLiquid: true,
        receiveWalletId: recipientWallet.id,
      )) {
        case Ok(:final value):
          swap = value;
        case Err(:final failure):
          return Err(_creationFailure(failure));
      }
      final preparation = await _liquidWalletRepository.buildPset(
        walletId: liquidWallet.id,
        address: swap.paymentAddress,
        amountSat: swap.paymentAmount,
        feeRate: const RelativeFee(25),
      );
      final String pset;
      switch (preparation) {
        case Ok(:final value):
          pset = value;
        case Err(:final failure):
          return Err(AutoswapExecutionFailure(failure.runtimeType.toString()));
      }
      final actualAmount = await _liquidWalletRepository.getAmountSentToAddress(
        pset: pset,
        address: swap.paymentAddress,
        walletId: liquidWallet.id,
      );
      final (_, actualFeeSat) = await _liquidWalletRepository
          .getPsetSizeAndAbsoluteFees(pset: pset);
      if (actualAmount != swap.paymentAmount) {
        return const Err(AutoswapPayinMismatchFailure());
      }
      if (balanceSat - actualAmount - actualFeeSat <
          settings.balanceThresholdSats) {
        return const Err(AutoswapTargetBalanceFailure());
      }
      final actualTotalFeePercent =
          providerFees.totalFeeAsPercentOfAmount(actualAmount) +
          (actualFeeSat / actualAmount * 100);
      if (!settings.withinFeeThreshold(actualTotalFeePercent)) {
        return Err(
          AutoswapFeeLimitExceededFailure(
            feePercent: actualTotalFeePercent,
            thresholdPercent: settings.feeThresholdPercent,
          ),
        );
      }
      final signed = await _liquidWalletRepository.signPset(
        walletId: liquidWallet.id,
        pset: pset,
      );
      final txid = await _broadcastLiquidTransaction.execute(
        signed,
        isTestnet: environment.requireHistoricalTestnet(),
      );
      final recorded = await _recordSwapLockup.execute(
        swapId: swap.id,
        txid: txid,
        lockupFeeSat: actualFeeSat,
      );
      if (recorded case Err(:final failure)) {
        log.warning(
          '[Autoswap] lockup broadcast but not recorded '
          '(${failure.runtimeType}); the swap status will backfill it',
        );
      }
      await _labelsFacade.store(
        NewLabel.tx(
          transactionId: txid,
          origin: liquidWallet.id,
          label: 'Auto-Transfer',
        ),
      );
      return Ok(swap.id);
    } catch (error) {
      return Err(AutoswapExecutionFailure(error.runtimeType.toString()));
    }
  }

  AutoswapFailure _creationFailure(SwapsFailure failure) => switch (failure) {
    SwapsBoltzUnavailableFailure() => AutoswapBoltzUnavailableFailure(
      failure.logMessage,
    ),
    SwapsAmountOutOfLimitsFailure() => const AutoswapAmountOutOfBoundsFailure(),
    _ => AutoswapProviderFailure(failure.runtimeType.toString()),
  };

  Future<Result<int, AutoswapFailure>> _estimateNetworkFee({
    required String walletId,
    required String address,
    required int amountSat,
  }) async {
    final preparation = await _liquidWalletRepository.buildPset(
      walletId: walletId,
      address: address,
      amountSat: amountSat,
      feeRate: const RelativeFee(25),
    );
    final String pset;
    switch (preparation) {
      case Ok(:final value):
        pset = value;
      case Err(:final failure):
        return Err(AutoswapExecutionFailure(failure.runtimeType.toString()));
    }
    final (_, feeSat) = await _liquidWalletRepository
        .getPsetSizeAndAbsoluteFees(pset: pset);
    return Ok(feeSat);
  }
}
