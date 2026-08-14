import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_provider_port.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';

class ExchangeAutoswapProvider implements AutoswapProviderPort {
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;
  final LiquidWalletRepository _liquidWalletRepository;
  final GetReceiveAddressUsecase _getReceiveAddress;
  final BroadcastLiquidTransactionUsecase _broadcastLiquidTransaction;
  final SwapFacade _swapFacade;
  final LabelsFacade _labelsFacade;

  const ExchangeAutoswapProvider(
    this._walletRepository,
    this._settingsRepository,
    this._liquidWalletRepository,
    this._getReceiveAddress,
    this._broadcastLiquidTransaction,
    this._swapFacade,
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

      final pendingResult = await _swapFacade.getPendingOrders();
      if (pendingResult case Ok(:final value)) {
        final pending = value
            .where(
              (order) =>
                  order.purpose == OrderSwapPurpose.autoswap &&
                  order.sourceWalletId == liquidWallet.id,
            )
            .firstOrNull;
        if (pending != null) {
          return await _resume(pending, liquidWallet, settings);
        }
      } else if (pendingResult case Err(:final failure)) {
        return Err(AutoswapProviderFailure(failure.runtimeType.toString()));
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

      final destination = await _getReceiveAddress.execute(
        walletId: recipientWallet.id,
      );
      final fallback = await _getReceiveAddress.execute(
        walletId: liquidWallet.id,
      );
      final networkFeeSat = await _estimateNetworkFee(
        wallet: liquidWallet,
        address: fallback.address,
        targetBalanceSat: settings.balanceThresholdSats,
      );
      final amountSat =
          balanceSat - settings.balanceThresholdSats - networkFeeSat;
      if (amountSat <= 0) {
        return const Err(AutoswapInsufficientBalanceFailure());
      }

      final orderEnvironment = environment.isTestnet
          ? OrderSwapEnvironment.testnet
          : OrderSwapEnvironment.mainnet;
      final quoteResult = await _swapFacade.getQuote(
        environment: orderEnvironment,
        amountSat: BigInt.from(amountSat),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.bitcoin,
      );
      if (quoteResult case Err(:final failure)) {
        return Err(AutoswapProviderFailure(failure.runtimeType.toString()));
      }
      final quote = (quoteResult as Ok<OrderSwapQuote, SwapFailure>).value;
      final totalFeeSat =
          BigInt.from(networkFeeSat) +
          (quote.inAmountSat - quote.outAmountSat).abs();
      final totalFeePercent = totalFeeSat.toDouble() / amountSat * 100;
      if (!settings.withinFeeThreshold(totalFeePercent)) {
        return Err(
          AutoswapFeeLimitExceededFailure(
            feePercent: totalFeePercent,
            thresholdPercent: settings.feeThresholdPercent,
          ),
        );
      }

      final createResult = await _swapFacade.createOrder(
        amountSat: BigInt.from(amountSat),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.bitcoin,
        destinationAddress: destination.address,
        fallbackAddress: fallback.address,
        purpose: OrderSwapPurpose.autoswap,
        environment: orderEnvironment,
        sourceWalletId: liquidWallet.id,
        destinationWalletId: recipientWallet.id,
        note: 'Auto-Transfer',
        quotedCounterpartAmountSat: quote.outAmountSat,
      );
      if (createResult case Err(:final failure)) {
        return Err(AutoswapProviderFailure(failure.runtimeType.toString()));
      }
      final record = (createResult as Ok<OrderSwapRecord, SwapFailure>).value;
      return await _prepareAndBroadcast(record, liquidWallet, settings);
    } catch (error) {
      return Err(AutoswapExecutionFailure(error.runtimeType.toString()));
    }
  }

  Future<Result<String, AutoswapFailure>> _resume(
    OrderSwapRecord record,
    Wallet wallet,
    AutoSwap settings,
  ) async {
    if (record.localStatus == OrderSwapLocalStatus.payinBroadcast ||
        record.localStatus == OrderSwapLocalStatus.payoutInProgress) {
      return Ok(record.localId);
    }
    if (record.localStatus == OrderSwapLocalStatus.broadcastUnknown) {
      final refreshResult = await _swapFacade.refreshOrder(record.localId);
      if (refreshResult case Err(:final failure)) {
        return Err(AutoswapProviderFailure(failure.runtimeType.toString()));
      }
      final refreshed =
          (refreshResult as Ok<OrderSwapRecord, SwapFailure>).value;
      final payinStatus = refreshed.order?.payinStatus.trim().toLowerCase();
      if (payinStatus == 'completed' ||
          refreshed.localStatus == OrderSwapLocalStatus.payinBroadcast ||
          refreshed.localStatus == OrderSwapLocalStatus.payoutInProgress ||
          refreshed.localStatus == OrderSwapLocalStatus.completed) {
        return Ok(refreshed.localId);
      }
      if (refreshed.localStatus == OrderSwapLocalStatus.broadcastUnknown &&
          refreshed.hasPreparedPayin) {
        return await _broadcast(refreshed, wallet);
      }
      return const Err(AutoswapPendingFailure());
    }
    if (record.hasPreparedPayin) return await _broadcast(record, wallet);
    if (record.order != null) {
      return await _prepareAndBroadcast(record, wallet, settings);
    }
    return const Err(AutoswapPendingFailure());
  }

  Future<Result<String, AutoswapFailure>> _prepareAndBroadcast(
    OrderSwapRecord record,
    Wallet wallet,
    AutoSwap settings,
  ) async {
    final order = record.order;
    if (order == null) return const Err(AutoswapPendingFailure());
    final pset = await _liquidWalletRepository.buildPset(
      walletId: wallet.id,
      address: order.payinAddress,
      amountSat: order.payinAmountSat.toInt(),
      feeRate: const RelativeFee(25),
    );
    final actualAmount = await _liquidWalletRepository.getAmountSentToAddress(
      pset: pset,
      address: order.payinAddress,
      walletId: wallet.id,
    );
    if (actualAmount != order.payinAmountSat.toInt()) {
      return const Err(AutoswapPayinMismatchFailure());
    }
    final (_, actualFeeSat) = await _liquidWalletRepository
        .getPsetSizeAndAbsoluteFees(pset: pset);
    final projectedBalanceSat =
        wallet.balanceSat.toInt() - actualAmount - actualFeeSat;
    if (projectedBalanceSat < settings.balanceThresholdSats) {
      return const Err(AutoswapTargetBalanceFailure());
    }
    final exchangeFeeSat = (order.payinAmountSat - order.payoutAmountSat).abs();
    final totalFeePercent =
        (exchangeFeeSat.toDouble() + actualFeeSat) / actualAmount * 100;
    if (!settings.withinFeeThreshold(totalFeePercent)) {
      return Err(
        AutoswapFeeLimitExceededFailure(
          feePercent: totalFeePercent,
          thresholdPercent: settings.feeThresholdPercent,
        ),
      );
    }
    final signed = await _liquidWalletRepository.signPset(
      walletId: wallet.id,
      pset: pset,
    );
    final preparedResult = await _swapFacade.savePreparedPayin(
      localId: record.localId,
      signedTransaction: signed,
      isPsbt: false,
    );
    if (preparedResult case Err(:final failure)) {
      return Err(AutoswapProviderFailure(failure.runtimeType.toString()));
    }
    return await _broadcast(
      (preparedResult as Ok<OrderSwapRecord, SwapFailure>).value,
      wallet,
    );
  }

  Future<Result<String, AutoswapFailure>> _broadcast(
    OrderSwapRecord record,
    Wallet wallet,
  ) async {
    final unknownResult = await _swapFacade.markBroadcastUnknown(
      record.localId,
    );
    if (unknownResult case Err(:final failure)) {
      return Err(AutoswapProviderFailure(failure.runtimeType.toString()));
    }
    final broadcasting =
        (unknownResult as Ok<OrderSwapRecord, SwapFailure>).value;
    final signedTransaction = broadcasting.signedPayinTransaction;
    if (signedTransaction == null) {
      return const Err(AutoswapPendingFailure());
    }
    final txid = await _broadcastLiquidTransaction.execute(
      signedTransaction,
      isTestnet: wallet.isTestnet,
    );
    final paidResult = await _swapFacade.markPayinBroadcast(
      localId: record.localId,
      transactionId: txid,
    );
    if (paidResult case Err(:final failure)) {
      return Err(AutoswapProviderFailure(failure.runtimeType.toString()));
    }
    await _labelsFacade.store(
      NewLabel.tx(
        transactionId: txid,
        origin: wallet.id,
        label: 'Auto-Transfer',
      ),
    );
    return Ok(record.localId);
  }

  Future<int> _estimateNetworkFee({
    required Wallet wallet,
    required String address,
    required int targetBalanceSat,
  }) async {
    final provisionalAmount = wallet.balanceSat.toInt() - targetBalanceSat;
    final pset = await _liquidWalletRepository.buildPset(
      walletId: wallet.id,
      address: address,
      amountSat: provisionalAmount,
      feeRate: const RelativeFee(25),
    );
    final (_, feeSat) = await _liquidWalletRepository
        .getPsetSizeAndAbsoluteFees(pset: pset);
    return feeSat;
  }
}
