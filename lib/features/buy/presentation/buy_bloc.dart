import 'dart:math' as math;

import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/buy/domain/label_completed_buy_order_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/buy/domain/accelerate_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:bb_mobile/features/buy/domain/cancel_abandoned_buy_payjoin_usecase.dart';
import 'package:bb_mobile/features/buy/domain/confirm_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/create_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/get_buy_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/buy/domain/load_buy_context_usecase.dart';
import 'package:bb_mobile/features/buy/domain/refresh_buy_order_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:primitives/primitives.dart';

part 'buy_bloc.freezed.dart';
part 'buy_event.dart';
part 'buy_state.dart';

class BuyBloc extends Bloc<BuyEvent, BuyState> {
  BuyBloc({
    required this._loadBuyContextUsecase,
    required this._confirmBuyOrderUsecase,
    required this._createBuyOrderUsecase,
    required this._refreshBuyOrderUsecase,
    required this._accelerateBuyOrderUsecase,
    required this._cancelAbandonedBuyPayjoinUsecase,
    required this._getBuyPayjoinEnabledUsecase,
    required this._labelCompletedBuyOrderUsecase,
  }) : super(const BuyState()) {
    on<_BuyStarted>(_onStarted);
    on<_BuyAmountInputChanged>(_onAmountInputChanged);
    on<_BuyCurrencyInputChanged>(_onCurrencyInputChanged);
    on<_BuyFiatCurrencyInputToggled>(_onFiatCurrencyInputToggled);
    on<_BuySelectedWalletChanged>(_onSelectedWalletChanged);
    on<_BuyBitcoinAddressInputChanged>(_onBitcoinAddressInputChanged);
    on<_BuyCreateOrder>(_onCreateOrder);
    on<_BuyRefreshOrder>(_onRefreshOrder);
    on<_BuyConfirmOrder>(_onConfirmOrder);
    on<_BuyPayjoinToggled>(_onPayjoinToggled);
    on<_BuyAccelerateTransactionPressed>(_onAccelerateTransactionPressed);
    on<_BuyAccelerateTransactionConfirmed>(_onAccelerateTransactionConfirmed);
  }

  final LoadBuyContextUsecase _loadBuyContextUsecase;
  final ConfirmBuyOrderUsecase _confirmBuyOrderUsecase;
  final CreateBuyOrderUsecase _createBuyOrderUsecase;
  final RefreshBuyOrderUsecase _refreshBuyOrderUsecase;
  final AccelerateBuyOrderUsecase _accelerateBuyOrderUsecase;
  final CancelAbandonedBuyPayjoinUsecase _cancelAbandonedBuyPayjoinUsecase;
  final GetBuyPayjoinEnabledUsecase _getBuyPayjoinEnabledUsecase;
  final LabelCompletedBuyOrderUsecase _labelCompletedBuyOrderUsecase;

  Future<void> _onStarted(_BuyStarted event, Emitter<BuyState> emit) async {
    // Cleared like every other handler does. Today `started` is dispatched
    // once at bloc creation so nothing stale can exist, but a retry or
    // re-entry flow would otherwise start on someone else's failure.
    emit(state.copyWith(failure: null));

    // `isStarted` is set on every path, success or not: the screen waits on it
    // before rendering anything at all.
    final UserSummary summary;
    final SettingsEntity settings;
    switch (await _loadBuyContextUsecase.userSummaryAndSettings()) {
      case Ok(:final value):
        summary = value.userSummary;
        settings = value.settings;
      case Err(:final failure):
        emit(state.copyWith(failure: failure, isStarted: true));
        return;
    }

    final payjoinEnabled = switch (await _getBuyPayjoinEnabledUsecase
        .execute()) {
      Ok(:final value) => value,
      Err() => false,
    };

    final preferredCurrency = summary.currency ?? settings.currencyCode;
    final balances = summary.balances.fold<Map<String, double>>({}, (
      map,
      balance,
    ) {
      map[balance.currencyCode] = balance.amount;
      return map;
    });
    // Only keep the currencies with a balance > 0.
    balances.removeWhere((key, value) => value <= 0);
    // If no currencies have a balance > 0, keep the preferred currency
    if (balances.isEmpty) {
      balances[preferredCurrency] = 0.0;
    }
    final currencyInput = balances[preferredCurrency] != null
        ? preferredCurrency
        : balances.keys.first;
    emit(
      state.copyWith(
        userSummary: summary,
        currencyInput: currencyInput,
        bitcoinUnit: settings.bitcoinUnit,
        balances: balances,
        payjoinGloballyEnabled: payjoinEnabled,
      ),
    );

    final List<Wallet> wallets;
    switch (await _loadBuyContextUsecase.wallets()) {
      case Ok(:final value):
        wallets = value;
      case Err(:final failure):
        emit(state.copyWith(failure: failure, isStarted: true));
        return;
    }
    // Always prefer the default liquid wallet if available, fallback to just
    // the first wallet if no default liquid wallet is found.
    final selectedWallet = wallets.isNotEmpty
        ? wallets.firstWhere(
            (w) => w.isDefault && w.isLiquid,
            orElse: () => wallets.first,
          )
        : null;

    emit(state.copyWith(wallets: wallets, selectedWallet: selectedWallet));

    final rate = await _loadBuyContextUsecase.satsToCurrency(
      currencyCode: currencyInput,
    );
    if (rate case Ok(:final value)) {
      emit(state.copyWith(exchangeRate: value));
    }

    emit(state.copyWith(isStarted: true));
  }

  Future<void> _onAmountInputChanged(
    _BuyAmountInputChanged event,
    Emitter<BuyState> emit,
  ) async {
    emit(state.copyWith(amountInput: event.amount));
  }

  Future<void> _onCurrencyInputChanged(
    _BuyCurrencyInputChanged event,
    Emitter<BuyState> emit,
  ) async {
    emit(state.copyWith(currencyInput: event.currencyCode));

    final rate = await _loadBuyContextUsecase.satsToCurrency(
      currencyCode: event.currencyCode,
    );
    if (rate case Ok(:final value)) {
      emit(state.copyWith(exchangeRate: value));
    }
  }

  Future<void> _onFiatCurrencyInputToggled(
    _BuyFiatCurrencyInputToggled event,
    Emitter<BuyState> emit,
  ) async {
    // Toggle the fiat currency input state.
    emit(state.copyWith(isFiatCurrencyInput: !state.isFiatCurrencyInput));
  }

  Future<void> _onSelectedWalletChanged(
    _BuySelectedWalletChanged event,
    Emitter<BuyState> emit,
  ) async {
    emit(state.copyWith(selectedWallet: event.wallet));
  }

  Future<void> _onBitcoinAddressInputChanged(
    _BuyBitcoinAddressInputChanged event,
    Emitter<BuyState> emit,
  ) async {
    emit(state.copyWith(bitcoinAddressInput: event.bitcoinAddress));
  }

  Future<void> _onCreateOrder(
    _BuyCreateOrder event,
    Emitter<BuyState> emit,
  ) async {
    try {
      await _cancelAbandonedPayjoin(state.buyOrder);
      // Clear any previous exceptions and reset the buy order so that we create
      //  a new one on every Continue button press as the data may have changed.
      emit(
        state.copyWith(isCreatingOrder: true, buyOrder: null, failure: null),
      );

      final wallet = state.selectedWallet;
      String toAddress;
      if (wallet != null) {
        // If a wallet is selected, fetch the receive address for it.
        final addressResult = await _loadBuyContextUsecase.receiveAddress(
          walletId: wallet.id,
        );
        switch (addressResult) {
          case Ok(:final value):
            toAddress = value.address;
          case Err(:final failure):
            emit(state.copyWith(failure: failure));
            return;
        }
      } else {
        // If no wallet is selected, use the bitcoin address input.
        toAddress = state.bitcoinAddressInput;
      }
      // A payjoin payout needs a wallet of ours, on-chain, plus a rough amount
      // — the exchange rejects a payjoin URI without one and replaces it with
      // what it actually pays. The decision belongs here rather than on the
      // confirmation screen: the URI is handed over with the order and no
      // endpoint can revise it afterwards. Everything else (an external
      // address, Liquid, an account outside the pilot) keeps placing the order
      // exactly as before.
      final usePayjoin = state.shouldUsePayjoin;

      final orderResult = await _createBuyOrderUsecase.execute(
        toAddress: toAddress,
        orderAmount: state.isFiatCurrencyInput
            ? FiatAmount(state.amount!)
            : BitcoinAmount(state.amountBtc!),
        currency: state.currency!,
        isLiquid: state.selectedWallet?.network.isLiquid == true,
        isOwner: true,
        payjoinWalletId: usePayjoin ? wallet!.id : null,
        payjoinAmountSat: usePayjoin ? state.amountSat : null,
      );

      switch (orderResult) {
        case Ok(:final value):
          emit(state.copyWith(buyOrder: value));
        case Err(:final failure):
          // Already logged at the boundary.
          emit(state.copyWith(failure: failure));
          // Refresh the exchange rate so the user can adjust the amount, in
          // case the amount was the reason for the failure.
          await _refreshExchangeRate(emit);
      }
    } finally {
      emit(state.copyWith(isCreatingOrder: false));
    }
  }

  /// Re-reads the rate after a failed order so the amount field shows a current
  /// number. Best-effort: a failure here must not replace the failure the user
  /// is being shown.
  Future<void> _refreshExchangeRate(Emitter<BuyState> emit) async {
    final rate = await _loadBuyContextUsecase.satsToCurrency(
      currencyCode: state.currency!.code,
    );
    if (rate case Ok(:final value)) {
      emit(state.copyWith(exchangeRate: value));
    }
  }

  Future<void> _onRefreshOrder(
    _BuyRefreshOrder event,
    Emitter<BuyState> emit,
  ) async {
    final orderId = event.orderId ?? state.buyOrder?.orderId;
    if (orderId == null) {
      log.severe(
        error: 'Refresh requested with no order to refresh',
        trace: StackTrace.current,
      );
      return;
    }

    try {
      emit(state.copyWith(isRefreshingOrder: true, failure: null));

      final refreshResult = await _refreshBuyOrderUsecase.execute(
        orderId: orderId,
      );
      final BuyOrder refreshedOrder;
      switch (refreshResult) {
        case Ok(:final value):
          refreshedOrder = value;
        case Err(:final failure):
          emit(state.copyWith(failure: failure));
          return;
      }
      final order = refreshedOrder.bip21URI == null
          ? refreshedOrder.copyWith(bip21URI: state.buyOrder?.bip21URI)
          : refreshedOrder;

      if (order.isExpired()) await _cancelAbandonedPayjoin(order);

      // The explicit order-completion event is the only legitimate writer
      // of privileged exchange labels.
      final labelled = await _labelCompletedBuyOrderUsecase.execute(
        order: order,
      );
      if (labelled case Err()) {
        log.info('Buy order completed without privileged labels');
      }

      emit(state.copyWith(buyOrder: order));
    } finally {
      emit(state.copyWith(isRefreshingOrder: false));
    }
  }

  Future<void> _onConfirmOrder(
    _BuyConfirmOrder event,
    Emitter<BuyState> emit,
  ) async {
    final orderId = state.buyOrder?.orderId;
    if (orderId == null) {
      log.severe(
        error: 'Confirm requested with no order to confirm',
        trace: StackTrace.current,
      );
      return;
    }

    try {
      emit(state.copyWith(isConfirmingOrder: true, failure: null));

      final confirmResult = await _confirmBuyOrderUsecase.execute(
        orderId: orderId,
      );
      final BuyOrder confirmedOrder;
      switch (confirmResult) {
        case Ok(:final value):
          confirmedOrder = value;
        case Err(:final failure):
          emit(state.copyWith(failure: failure));
          return;
      }
      final order = confirmedOrder.bip21URI == null
          ? confirmedOrder.copyWith(bip21URI: state.buyOrder?.bip21URI)
          : confirmedOrder;

      emit(state.copyWith(buyOrder: order));
    } finally {
      emit(state.copyWith(isConfirmingOrder: false));
    }
  }

  void _onPayjoinToggled(_BuyPayjoinToggled event, Emitter<BuyState> emit) {
    emit(state.copyWith(isPayjoinEnabled: event.enabled));
  }

  Future<void> _cancelAbandonedPayjoin(BuyOrder? order) async {
    final cancelled = await _cancelAbandonedBuyPayjoinUsecase.execute(order);
    if (cancelled case Err()) {
      log.info('Abandoned buy Payjoin session was left in place');
    }
  }

  @override
  Future<void> close() async {
    await _cancelAbandonedPayjoin(state.buyOrder);
    return super.close();
  }

  Future<void> _onAccelerateTransactionPressed(
    _BuyAccelerateTransactionPressed event,
    Emitter<BuyState> emit,
  ) async {
    emit(state.copyWith(failure: null));

    final refreshResult = await _refreshBuyOrderUsecase.execute(
      orderId: event.orderId,
    );
    final BuyOrder order;
    switch (refreshResult) {
      case Ok(:final value):
        order = value;
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
        return;
    }

    // Both are needed to price the acceleration, so either failing stops it.
    final (feesResult, rateResult) = await (
      _loadBuyContextUsecase.networkFees(isLiquid: false),
      _loadBuyContextUsecase.satsToCurrency(currencyCode: order.payinCurrency),
    ).wait;
    final FeeOptions networkFees;
    switch (feesResult) {
      case Ok(:final value):
        networkFees = value;
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
        return;
    }
    final double exchangeRate;
    switch (rateResult) {
      case Ok(:final value):
        exchangeRate = value;
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
        return;
    }

    emit(
      state.copyWith(
        buyOrder: order,
        accelerationNetworkFees: networkFees,
        exchangeRate: exchangeRate,
      ),
    );
  }

  Future<void> _onAccelerateTransactionConfirmed(
    _BuyAccelerateTransactionConfirmed event,
    Emitter<BuyState> emit,
  ) async {
    final orderId = state.buyOrder?.orderId;
    if (orderId == null) {
      log.severe(
        error: 'Acceleration requested with no order to accelerate',
        trace: StackTrace.current,
      );
      return;
    }

    try {
      emit(state.copyWith(isAcceleratingOrder: true, failure: null));

      final accelerateResult = await _accelerateBuyOrderUsecase.execute(
        orderId,
      );
      BuyOrder order;
      switch (accelerateResult) {
        case Ok(:final value):
          order = value;
        case Err(:final failure):
          emit(state.copyWith(failure: failure));
          return;
      }

      while (order.unbatchedBuyOnchainFees == null) {
        // Wait for the unbatched fees to be available
        await Future.delayed(const Duration(seconds: 3));
        final polled = await _refreshBuyOrderUsecase.execute(
          orderId: order.orderId,
        );
        switch (polled) {
          case Ok(:final value):
            order = value;
          case Err(:final failure):
            emit(state.copyWith(failure: failure));
            return;
        }
      }

      emit(state.copyWith(buyOrder: order));
    } finally {
      emit(state.copyWith(isAcceleratingOrder: false));
    }
  }
}
