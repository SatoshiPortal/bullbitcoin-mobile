import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_provider_port.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';

class BoltzAutoswapProvider implements AutoswapProviderPort {
  final BoltzSwapRepository _swapRepository;
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;
  final LiquidWalletRepository _liquidWalletRepository;
  final GetReceiveAddressUsecase _getReceiveAddress;
  final BroadcastLiquidTransactionUsecase _broadcastLiquidTransaction;
  final LabelsFacade _labelsFacade;

  const BoltzAutoswapProvider(
    this._swapRepository,
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
      final wallets = await _walletRepository.getWallets(
        environment: environment,
      );
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

      final existing =
          (await _swapRepository.getOngoingSwaps(walletId: liquidWallet.id))
              .whereType<ChainSwap>()
              .where(
                (swap) =>
                    swap.type == SwapType.liquidToBitcoin &&
                    swap.sendWalletId == liquidWallet.id,
              )
              .firstOrNull;
      if (existing != null) {
        return existing.sendTxid == null
            ? const Err(AutoswapPendingFailure())
            : Ok(existing.id);
      }

      final balanceSat = liquidWallet.balanceSat.toInt();
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
      final networkFeeSat = await _estimateNetworkFee(
        walletId: liquidWallet.id,
        address: fallback.address,
        amountSat: balanceSat - settings.balanceThresholdSats,
      );
      final amountSat =
          balanceSat - settings.balanceThresholdSats - networkFeeSat;
      if (amountSat <= 0) {
        return const Err(AutoswapInsufficientBalanceFailure());
      }

      final (limits, providerFees) = await _swapRepository.getSwapLimitsAndFees(
        SwapType.liquidToBitcoin,
      );
      if (amountSat < limits.min || amountSat > limits.max) {
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

      final swap = await _swapRepository.createLiquidToBitcoinSwap(
        sendWalletId: liquidWallet.id,
        amountSat: amountSat,
        btcElectrumUrl: environment.isTestnet
            ? ApiServiceConstants.publicElectrumTestUrl
            : ApiServiceConstants.bbElectrumUrl,
        lbtcElectrumUrl: environment.isTestnet
            ? ApiServiceConstants.publicliquidElectrumTestUrlPath
            : ApiServiceConstants.bbLiquidElectrumUrlPath,
        receiveWalletId: recipientWallet.id,
      );
      final pset = await _liquidWalletRepository.buildPset(
        walletId: liquidWallet.id,
        address: swap.paymentAddress,
        amountSat: swap.paymentAmount,
        feeRate: const RelativeFee(25),
      );
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
        isTestnet: environment.isTestnet,
      );
      await _swapRepository.updatePaidSendSwap(
        swapId: swap.id,
        txid: txid,
        absoluteFees: actualFeeSat,
      );
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

  Future<int> _estimateNetworkFee({
    required String walletId,
    required String address,
    required int amountSat,
  }) async {
    final pset = await _liquidWalletRepository.buildPset(
      walletId: walletId,
      address: address,
      amountSat: amountSat,
      feeRate: const RelativeFee(25),
    );
    final (_, feeSat) = await _liquidWalletRepository
        .getPsetSizeAndAbsoluteFees(pset: pset);
    return feeSat;
  }
}
