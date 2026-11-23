import 'package:address_view/address_view.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:fees/fees.dart';
import 'package:preferences/preferences.dart';
import 'package:swaps/swaps.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:address_view/address_view.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_provider_port.dart';
import 'package:labels/labels.dart';
import 'package:bull_logger/bull_logger.dart';

class BoltzAutoswapProvider implements AutoswapProviderPort {
  final GetSwapLimitsAndFeesUsecase _getSwapLimitsAndFees;
  final CreateLiquidToBitcoinSwapUsecase _createLiquidToBitcoinSwap;
  final RecordSwapLockupUsecase _recordSwapLockup;
  final RecordPendingSwapLockupUsecase _recordPendingLockup;
  final DropPendingSwapLockupUsecase _dropPendingLockup;
  final WalletRepository _walletRepository;
  final Preferences _settingsRepository;
  final Spend _spend;
  final AddressView _getReceiveAddress;
  final Labels _labelsFacade;

  const BoltzAutoswapProvider(
    this._getSwapLimitsAndFees,
    this._createLiquidToBitcoinSwap,
    this._recordSwapLockup,
    this._recordPendingLockup,
    this._dropPendingLockup,
    this._walletRepository,
    this._settingsRepository,
    this._spend,
    this._getReceiveAddress,
    this._labelsFacade,
  );

  @override
  Future<Result<String, AutoswapFailure>> execute(AutoSwap settings) async {
    try {
      final environment = ((await _settingsRepository.fetch()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      )).environment;
      if (environment.networkEnv == NetworkEnv.regtest) {
        return const Err(AutoswapUnsupportedWalletFailure());
      }
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
      final WalletAddress fallback;
      switch (await _getReceiveAddress.receiveAddress(
        walletId: liquidWallet.id,
      )) {
        case Ok(:final value):
          fallback = value;
        case Err():
          return const Err(
            AutoswapExecutionFailure('Receive address unavailable'),
          );
      }
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
      switch (await _createLiquidToBitcoinSwap.execute(
        sendWalletId: liquidWallet.id,
        amountSat: amountSat,
        destination: ToWallet(recipientWallet.id),
      )) {
        case Ok(:final value):
          swap = value;
        case Err(:final failure):
          return Err(_creationFailure(failure));
      }
      final preparation = await _spend.prepareLiquid(
        walletId: liquidWallet.id,
        address: swap.paymentAddress,
        amountSat: swap.paymentAmount,
        feeRate: NetworkFeeRelayPolicy.minRelay,
      );
      final PreparedLiquidSpend prepared;
      switch (preparation) {
        case Ok(:final value):
          prepared = value;
        case Err(:final failure):
          return Err(AutoswapExecutionFailure(failure.runtimeType.toString()));
      }
      final actualAmount = prepared.amountSent.value.toInt();
      final actualFeeSat = prepared.fee.value.toInt();
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
      final SignedLiquidSpend signed;
      switch (await _spend.signLiquid(prepared: prepared)) {
        case Ok(:final value):
          signed = value;
        case Err(:final failure):
          return Err(AutoswapExecutionFailure(failure.runtimeType.toString()));
      }
      // Stored before the broadcast so an unclear outcome is settled from
      // this exact transaction and the swap can never be funded twice.
      if (await _recordPendingLockup.execute(
            swapId: swap.id,
            signedTx: signed.signedPset,
          )
          case Err(:final failure)) {
        return Err(AutoswapExecutionFailure(failure.runtimeType.toString()));
      }
      final String txid;
      switch (await _spend.broadcastLiquid(signed)) {
        case Ok(:final value):
          txid = value.txid;
        case Err(:final failure):
          if (failure is SpendBroadcastRejectedFailure ||
              failure is SpendDeveloperAuthorizationFailure) {
            final _ = await _dropPendingLockup.execute(swap.id);
          }
          return Err(AutoswapExecutionFailure(failure.runtimeType.toString()));
      }
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
          label: LabelSystem.autoSwap.label,
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
    final preparation = await _spend.prepareLiquid(
      walletId: walletId,
      address: address,
      amountSat: amountSat,
      feeRate: NetworkFeeRelayPolicy.minRelay,
    );
    return preparation
        .map((value) => value.fee.value.toInt())
        .mapErr(
          (failure) => AutoswapExecutionFailure(failure.runtimeType.toString()),
        );
  }
}
