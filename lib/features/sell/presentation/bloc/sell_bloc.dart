import 'dart:async';

import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/features/sell/domain/usecases/confirm_sell_payin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/estimate_sell_payin_fees_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/recalculate_sell_payin_fees_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/start_sell_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/get_sell_order_status_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart' hide Network;
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/features/sell/domain/usecases/load_sell_utxos_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/create_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/refresh_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bip21_uri/bip21_uri.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sell_bloc.freezed.dart';
part 'sell_event.dart';
part 'sell_state.dart';

class SellBloc extends Bloc<SellEvent, SellState> {
  SellBloc({
    required this._startSellUsecase,
    required this._confirmSellPayinUsecase,
    required this._createSellOrderUsecase,
    required this._refreshSellOrderUsecase,
    required this._estimateSellPayinFeesUsecase,
    required this._recalculateSellPayinFeesUsecase,
    required this._loadSellUtxosUsecase,
    required this._getSellOrderStatusUsecase,
  }) : super(const SellState.initial()) {
    on<SellStarted>(_onStarted);
    on<SellAmountInputContinuePressed>(_onAmountInputContinuePressed);
    on<SellWalletSelected>(_onWalletSelected);
    on<SellExternalWalletNetworkSelected>(_onExternalWalletNetworkSelected);
    on<SellOrderRefreshTimePassed>(_onOrderRefreshTimePassed);
    on<SellSendPaymentConfirmed>(
      _onSendPaymentConfirmed,
      transformer: droppable(), // Prevent multiple simultaneous confirmations
    );
    on<SellPollOrderStatus>(_onPollOrderStatus);
    on<SellReplaceByFeeChanged>(_onReplaceByFeeChanged);
    on<SellUtxosSelected>(_onUtxosSelected);
    on<SellLoadUtxos>(_onLoadUtxos);
  }

  final StartSellUsecase _startSellUsecase;
  final ConfirmSellPayinUsecase _confirmSellPayinUsecase;
  final CreateSellOrderUsecase _createSellOrderUsecase;
  final RefreshSellOrderUsecase _refreshSellOrderUsecase;
  final EstimateSellPayinFeesUsecase _estimateSellPayinFeesUsecase;
  final RecalculateSellPayinFeesUsecase _recalculateSellPayinFeesUsecase;
  final LoadSellUtxosUsecase _loadSellUtxosUsecase;
  final GetSellOrderStatusUsecase _getSellOrderStatusUsecase;
  Timer? _pollingTimer;

  Future<void> _onStarted(SellStarted event, Emitter<SellState> emit) async {
    switch (await _startSellUsecase.execute()) {
      case Ok(:final value):
        emit(
          SellState.amountInput(
            userSummary: value.userSummary,
            bitcoinUnit: value.bitcoinUnit,
          ),
        );
      case Err(:final failure):
        emit(SellState.initial(failure: failure));
    }
  }

  Future<void> _onAmountInputContinuePressed(
    SellAmountInputContinuePressed event,
    Emitter<SellState> emit,
  ) async {
    // We should be on a clean SellWalletSelectionState state here
    final amountInputState = state.toCleanAmountInputState;
    if (amountInputState == null) {
      log.severe(
        error: 'Expected to be on SellAmountInputState',
        trace: StackTrace.current,
      );
      return;
    }
    emit(amountInputState);

    OrderAmount orderAmount;
    if (event.isFiatCurrencyInput) {
      orderAmount = FiatAmount(double.parse(event.amountInput));
    } else {
      final amountBtc = amountInputState.bitcoinUnit == BitcoinUnit.sats
          ? ConvertAmount.satsToBtc(int.parse(event.amountInput))
          : double.parse(event.amountInput);
      orderAmount = BitcoinAmount(amountBtc);
    }

    emit(
      amountInputState.toWalletSelectionState(
        orderAmount: orderAmount,
        fiatCurrency: event.fiatCurrency,
      ),
    );
  }

  Future<void> _onWalletSelected(
    SellWalletSelected event,
    Emitter<SellState> emit,
  ) async {
    final walletSelectionState = state.toCleanWalletSelectionState;
    if (walletSelectionState == null) {
      log.severe(
        error: 'Expected to be on SellWalletSelectionState',
        trace: StackTrace.current,
      );
      return;
    }
    emit(walletSelectionState.copyWith(isCreatingSellOrder: true, error: null));

    final int absoluteFees;
    final double exchangeRateEstimate;
    switch (await _estimateSellPayinFeesUsecase.execute(
      wallet: event.wallet,
      orderAmount: walletSelectionState.orderAmount,
      fiatCurrency: walletSelectionState.fiatCurrency,
    )) {
      case Err(:final failure):
        emit(
          walletSelectionState.copyWith(
            error: failure,
            isCreatingSellOrder: false,
          ),
        );
        return;
      case Ok(:final value):
        absoluteFees = value.absoluteFees;
        exchangeRateEstimate = value.exchangeRateEstimate;
    }

    switch (await _createSellOrderUsecase.execute(
      orderAmount: walletSelectionState.orderAmount,
      currency: walletSelectionState.fiatCurrency,
      network: event.wallet.isLiquid
          ? OrderBitcoinNetwork.liquid
          : OrderBitcoinNetwork.bitcoin,
    )) {
      case Err(:final failure):
        emit(
          walletSelectionState.copyWith(
            error: failure,
            isCreatingSellOrder: false,
          ),
        );
        return;
      case Ok(:final value):
        if (!event.wallet.isLiquid) {
          final List<WalletUtxo> utxos;
          switch (await _loadSellUtxosUsecase.execute(
            walletId: event.wallet.id,
          )) {
            case Err(:final failure):
              emit(
                walletSelectionState.copyWith(
                  error: failure,
                  isCreatingSellOrder: false,
                ),
              );
              return;
            case Ok(value: final loadedUtxos):
              utxos = loadedUtxos;
          }
          emit(
            walletSelectionState.toSendPaymentState(
              selectedWallet: event.wallet,
              createdSellOrder: value,
              absoluteFees: absoluteFees,
              utxos: utxos,
              exchangeRateEstimate: exchangeRateEstimate,
            ),
          );
        } else {
          emit(
            walletSelectionState.toSendPaymentState(
              selectedWallet: event.wallet,
              createdSellOrder: value,
              absoluteFees: absoluteFees,
              exchangeRateEstimate: exchangeRateEstimate,
            ),
          );
        }
        _startPolling();
    }
  }

  Future<void> _onExternalWalletNetworkSelected(
    SellExternalWalletNetworkSelected event,
    Emitter<SellState> emit,
  ) async {
    // We should be on a SellWalletSelection or SellPaymentState and return
    //  to a clean SellWalletSelectionState state
    final walletSelectionState = state.toCleanWalletSelectionState;
    if (walletSelectionState == null) {
      log.severe(
        error: 'Expected to be on SellWalletSelectionState',
        trace: StackTrace.current,
      );
      return;
    }
    emit(walletSelectionState.copyWith(isCreatingSellOrder: true));

    switch (await _createSellOrderUsecase.execute(
      orderAmount: walletSelectionState.orderAmount,
      currency: walletSelectionState.fiatCurrency,
      network: event.network,
    )) {
      case Err(:final failure):
        emit(
          walletSelectionState.copyWith(
            error: failure,
            isCreatingSellOrder: false,
          ),
        );
      case Ok(:final value):
        emit(
          walletSelectionState.toReceivePaymentState(createdSellOrder: value),
        );
        _startPolling();
    }
  }

  Future<void> _onOrderRefreshTimePassed(
    SellOrderRefreshTimePassed event,
    Emitter<SellState> emit,
  ) async {
    // We should be on a SellPaymentState
    final paymentState = state.toCleanPaymentState;
    if (paymentState == null) {
      log.severe(
        error: 'Expected to be on SellPaymentState',
        trace: StackTrace.current,
      );
      return;
    }

    switch (await _refreshSellOrderUsecase.execute(
      orderId: paymentState.sellOrder.orderId,
    )) {
      case Ok(:final value):
        emit(paymentState.copyWith(sellOrder: value));
      case Err(:final failure):
        emit(paymentState.copyWith(error: failure));
    }
  }

  Future<void> _onSendPaymentConfirmed(
    SellSendPaymentConfirmed event,
    Emitter<SellState> emit,
  ) async {
    // We should be on a SellPaymentState
    final sellPaymentState = state.toCleanPaymentState;
    if (sellPaymentState == null) {
      log.severe(
        error: 'Expected to be on SellPaymentState',
        trace: StackTrace.current,
      );
      return;
    }

    final wallet = sellPaymentState.selectedWallet;
    if (wallet == null) {
      emit(
        sellPaymentState.copyWith(
          error: const SellUnexpectedFailure(),
          isConfirmingPayment: false,
        ),
      );
      return;
    }

    emit(sellPaymentState.copyWith(isConfirmingPayment: true));

    switch (await _confirmSellPayinUsecase.execute(
      wallet: wallet,
      sellOrder: sellPaymentState.sellOrder,
      absoluteFees: sellPaymentState.absoluteFees,
      selectedInputs: sellPaymentState.selectedUtxos,
      replaceByFee: sellPaymentState.replaceByFee,
    )) {
      case Err(:final failure):
        emit(
          sellPaymentState.copyWith(error: failure, isConfirmingPayment: false),
        );
        return;
      case Ok(:final value):
        final updatedState = value.updatedAbsoluteFees != null
            ? sellPaymentState.copyWith(absoluteFees: value.updatedAbsoluteFees)
            : sellPaymentState;
        // 5s delay gives backend time to register the 0 conf
        await Future.delayed(const Duration(seconds: 5));
        emit(updatedState.toSuccessState(sellOrder: updatedState.sellOrder));
    }
  }

  Future<void> _onPollOrderStatus(
    SellPollOrderStatus event,
    Emitter<SellState> emit,
  ) async {
    if (state is! SellPaymentState) return;

    final sellPaymentState = state as SellPaymentState;

    final SellOrder latestOrder;
    switch (await _getSellOrderStatusUsecase.execute(
      orderId: sellPaymentState.sellOrder.orderId,
    )) {
      case Ok(:final value):
        latestOrder = value;
      case Err(:final failure):
        emit(sellPaymentState.copyWith(error: failure));
        return;
    }

    final payinStatus = latestOrder.payinStatus;

    if (payinStatus == OrderPayinStatus.inProgress ||
        payinStatus == OrderPayinStatus.awaitingConfirmation ||
        payinStatus == OrderPayinStatus.completed) {
      _stopPolling();
      emit(
        sellPaymentState
            .copyWith(sellOrder: latestOrder, isPolling: false)
            .toSuccessState(sellOrder: latestOrder),
      );
    } else {
      emit(sellPaymentState.copyWith(sellOrder: latestOrder, isPolling: true));
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      add(const SellEvent.pollOrderStatus());
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _onReplaceByFeeChanged(
    SellReplaceByFeeChanged event,
    Emitter<SellState> emit,
  ) async {
    if (state is! SellPaymentState) return;

    final sellPaymentState = state as SellPaymentState;
    emit(sellPaymentState.copyWith(replaceByFee: event.replaceByFee));
    await _recalculateFees(emit);
  }

  Future<void> _onUtxosSelected(
    SellUtxosSelected event,
    Emitter<SellState> emit,
  ) async {
    if (state is! SellPaymentState) return;

    final sellPaymentState = state as SellPaymentState;
    final selectedUtxos = event.utxos;

    emit(sellPaymentState.copyWith(selectedUtxos: selectedUtxos));
    await _recalculateFees(emit);
  }

  Future<void> _onLoadUtxos(
    SellLoadUtxos event,
    Emitter<SellState> emit,
  ) async {
    if (state is! SellPaymentState) return;

    final sellPaymentState = state as SellPaymentState;
    final wallet = sellPaymentState.selectedWallet;
    if (wallet == null) return;

    switch (await _loadSellUtxosUsecase.execute(walletId: wallet.id)) {
      case Ok(:final value):
        emit(sellPaymentState.copyWith(utxos: value));
      case Err(:final failure):
        emit(sellPaymentState.copyWith(error: failure));
    }
  }

  Future<void> _recalculateFees(Emitter<SellState> emit) async {
    if (state is! SellPaymentState) return;

    final sellPaymentState = state as SellPaymentState;
    final wallet = sellPaymentState.selectedWallet;
    if (wallet == null) return;

    final payinAmountSat = ConvertAmount.btcToSats(
      sellPaymentState.sellOrder.payinAmount,
    );

    switch (await _recalculateSellPayinFeesUsecase.execute(
      wallet: wallet,
      amountSat: payinAmountSat,
      selectedInputs: sellPaymentState.selectedUtxos,
      replaceByFee: sellPaymentState.replaceByFee,
    )) {
      case Ok(:final value):
        emit(sellPaymentState.copyWith(absoluteFees: value));
      case Err(:final failure):
        emit(sellPaymentState.copyWith(error: failure));
    }
  }

  @override
  Future<void> close() {
    _stopPolling();
    return super.close();
  }
}
