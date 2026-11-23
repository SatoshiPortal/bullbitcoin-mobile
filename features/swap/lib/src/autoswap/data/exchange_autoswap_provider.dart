import 'package:address_view/address_view.dart';
import 'package:fees/fees.dart';
import 'package:preferences/preferences.dart';
import 'package:swaps/swaps.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';
import 'package:swap_feature/src/domain/usecases/load_swap_wallets_usecase.dart';
import 'package:swap_feature/src/domain/entities/swap_wallet.dart';
import 'package:swap_feature/src/autoswap/domain/autoswap_provider_port.dart';
import 'package:labels/labels.dart';

class ExchangeAutoswapProvider implements AutoswapProviderPort {
  /// Fallback when the server sends no Retry-After.
  static const _createRetryDelay = Duration(seconds: 5);

  /// Longest wait worth taking inline. `Retry-After` is server-controlled and
  /// unbounded, and sleeping on it would park the watcher (its in-flight guard
  /// drops every sync meanwhile) and stall `dispose`, which awaits the run.
  /// Past this the quote is stale anyway, so the next sync retries instead.
  /// Matches the spacing `RefreshOrderSwapsUsecase` uses on the same API.
  static const _maxCreateRetryDelay = Duration(seconds: 30);

  final LoadSwapWalletsUsecase _walletRepository;
  final Preferences _settingsRepository;
  final Spend _spend;
  final AddressView _getReceiveAddress;
  final OrderSwaps _orders;
  final Labels _labelsFacade;
  final Future<void> Function(Duration) _delay;

  ExchangeAutoswapProvider(
    this._walletRepository,
    this._settingsRepository,
    this._spend,
    this._getReceiveAddress,
    this._orders,
    this._labelsFacade, {
    Future<void> Function(Duration)? delay,
  }) : _delay = delay ?? Future<void>.delayed;

  @override
  Future<Result<String, AutoswapFailure>> execute(AutoSwap settings) async {
    try {
      final environment = ((await _settingsRepository.fetch()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      )).environment;
      final List<SwapWallet> wallets;
      switch (await _walletRepository.execute(environment.networkEnv)) {
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

      final pendingResult = await _orders.getPendingOrders();
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

      final balanceSat = liquidWallet.balanceSat?.toInt();
      if (balanceSat == null) {
        return const Err(AutoswapExecutionFailure('SwapWallet unavailable'));
      }
      if (!settings.passedRequiredBalance(balanceSat)) {
        return Err(
          AutoswapInsufficientBalanceFailure(
            currentBalanceSats: balanceSat,
            requiredThresholdSats: settings.triggerBalanceSats,
          ),
        );
      }

      final WalletAddress destination;
      switch (await _getReceiveAddress.receiveAddress(
        walletId: recipientWallet.id,
      )) {
        case Ok(:final value):
          destination = value;
        case Err():
          return const Err(
            AutoswapExecutionFailure('Receive address unavailable'),
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
        balanceSat: balanceSat,
        wallet: liquidWallet,
        address: fallback.address,
        targetBalanceSat: settings.balanceThresholdSats,
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

      final orderEnvironment = environment.requireHistoricalTestnet()
          ? OrderSwapEnvironment.testnet
          : OrderSwapEnvironment.mainnet;
      final quoteResult = await _orders.getQuote(
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

      Future<Result<OrderSwapRecord, SwapFailure>> create() =>
          _orders.createOrder(
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
            note: LabelSystem.autoSwap.label,
            quotedCounterpartAmountSat: quote.outAmountSat,
          );

      var createResult = await create();
      // The quote just used the rate-limit slot, so this call is the one that
      // gets refused. Nothing was created server-side, so one retry is safe.
      // Keep the wait short: the quote it submits goes stale.
      if (createResult case Err(:final failure)
          when failure is SwapRateLimitedFailure) {
        final wait = failure.retryAfter ?? _createRetryDelay;
        if (wait <= _maxCreateRetryDelay) {
          await _delay(wait);
          createResult = await create();
        }
      }
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
    SwapWallet wallet,
    AutoSwap settings,
  ) async {
    if (record.localStatus == OrderSwapLocalStatus.payinBroadcast ||
        record.localStatus == OrderSwapLocalStatus.payoutInProgress) {
      return Ok(record.localId);
    }
    if (record.localStatus == OrderSwapLocalStatus.broadcastUnknown) {
      final refreshResult = await _orders.refreshOrder(record.localId);
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
    SwapWallet wallet,
    AutoSwap settings,
  ) async {
    final order = record.order;
    if (order == null) return const Err(AutoswapPendingFailure());
    final preparation = await _spend.prepareLiquid(
      walletId: wallet.id,
      address: order.payinAddress,
      amountSat: order.payinAmountSat.toInt(),
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
    if (actualAmount != order.payinAmountSat.toInt()) {
      return const Err(AutoswapPayinMismatchFailure());
    }
    final actualFeeSat = prepared.fee.value.toInt();
    final balance = wallet.balanceSat;
    if (balance == null) {
      return const Err(AutoswapExecutionFailure('SwapWallet unavailable'));
    }
    final projectedBalanceSat = balance.toInt() - actualAmount - actualFeeSat;
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
    final SignedLiquidSpend signed;
    switch (await _spend.signLiquid(prepared: prepared)) {
      case Ok(:final value):
        signed = value;
      case Err(:final failure):
        return Err(AutoswapExecutionFailure(failure.runtimeType.toString()));
    }
    final preparedResult = await _orders.savePreparedPayin(
      localId: record.localId,
      signedTransaction: signed.signedPset,
      isPsbt: false,
    );
    if (preparedResult case Err(:final failure)) {
      return Err(AutoswapProviderFailure(failure.runtimeType.toString()));
    }
    return await _broadcast(
      (preparedResult as Ok<OrderSwapRecord, SwapFailure>).value,
      wallet,
      signed: signed,
    );
  }

  Future<Result<String, AutoswapFailure>> _broadcast(
    OrderSwapRecord record,
    SwapWallet wallet, {
    SignedLiquidSpend? signed,
  }) async {
    final order = record.order;
    final storedPset = record.signedPayinTransaction;
    if (record.purpose != OrderSwapPurpose.autoswap ||
        record.inNetwork != OrderSwapNetwork.liquid ||
        record.sourceWalletId != wallet.id ||
        record.environment !=
            (wallet.network.isMainnet
                ? OrderSwapEnvironment.mainnet
                : OrderSwapEnvironment.testnet) ||
        order == null ||
        storedPset == null ||
        record.payinIsPsbt != false ||
        (signed != null && signed.signedPset != storedPset)) {
      return const Err(AutoswapPayinMismatchFailure());
    }
    final unknownResult = await _orders.markBroadcastUnknown(record.localId);
    if (unknownResult case Err(:final failure)) {
      return Err(AutoswapProviderFailure(failure.runtimeType.toString()));
    }
    final broadcasting =
        (unknownResult as Ok<OrderSwapRecord, SwapFailure>).value;
    if (broadcasting.signedPayinTransaction != storedPset ||
        broadcasting.payinIsPsbt != false) {
      return const Err(AutoswapPendingFailure());
    }
    final receipt = signed == null
        ? await _spend.resumeLiquidPayin(
            signedPset: storedPset,
            walletId: wallet.id,
            network: wallet.network as LiquidNetwork,
            address: order.payinAddress,
            amount: Sats(order.payinAmountSat),
          )
        : await _spend.broadcastLiquid(signed);
    final String txid;
    switch (receipt) {
      case Ok(:final value):
        txid = value.txid;
      case Err(
        failure: SpendBroadcastOutcomeUnknownFailure() ||
            SpendAlreadyInChainFailure(),
      ):
        return const Err(AutoswapPendingFailure());
      case Err(failure: SpendSignedTransactionMismatchFailure()):
        return const Err(AutoswapPayinMismatchFailure());
      case Err(:final failure):
        return Err(AutoswapExecutionFailure(failure.runtimeType.toString()));
    }
    final paidResult = await _orders.markPayinBroadcast(
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
        label: LabelSystem.autoSwap.label,
      ),
    );
    return Ok(record.localId);
  }

  Future<Result<int, AutoswapFailure>> _estimateNetworkFee({
    required int balanceSat,
    required SwapWallet wallet,
    required String address,
    required int targetBalanceSat,
  }) async {
    final provisionalAmount = balanceSat - targetBalanceSat;
    final preparation = await _spend.prepareLiquid(
      walletId: wallet.id,
      address: address,
      amountSat: provisionalAmount,
      feeRate: NetworkFeeRelayPolicy.minRelay,
    );
    return preparation
        .map((value) => value.fee.value.toInt())
        .mapErr(
          (failure) => AutoswapExecutionFailure(failure.runtimeType.toString()),
        );
  }
}
