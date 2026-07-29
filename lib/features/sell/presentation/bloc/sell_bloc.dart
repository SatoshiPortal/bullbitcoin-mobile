import 'dart:async';

import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/errors/sell_error.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
import 'package:bb_mobile/core/utils/liquid_tx.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart' hide Network;
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/sell/domain/create_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/refresh_sell_order_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bip21_uri/bip21_uri.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sell_bloc.freezed.dart';
part 'sell_event.dart';
part 'sell_state.dart';

class SellBloc extends Bloc<SellEvent, SellState> {
  SellBloc({
    required this._getExchangeUserSummaryUsecase,
    required this._getSettingsUsecase,
    required this._createSellOrderUsecase,
    required this._refreshSellOrderUsecase,
    required this._prepareBitcoinSendUsecase,
    required this._prepareLiquidSendUsecase,
    required this._signBitcoinTxUsecase,
    required this._signLiquidTxUsecase,
    required this._broadcastBitcoinTransactionUsecase,
    required this._broadcastLiquidTransactionUsecase,
    required this._getNetworkFeesUsecase,
    required this._calculateLiquidAbsoluteFeesUsecase,
    required this._calculateBitcoinAbsoluteFeesUsecase,
    required this._convertSatsToCurrencyAmountUsecase,
    required this._getAddressAtIndexUsecase,
    required this._getWalletUtxosUsecase,
    required this._getOrderUsecase,
    required this._labelsFacade,
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

  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final GetSettingsUsecase _getSettingsUsecase;
  final CreateSellOrderUsecase _createSellOrderUsecase;
  final RefreshSellOrderUsecase _refreshSellOrderUsecase;
  final PrepareBitcoinSendUsecase _prepareBitcoinSendUsecase;
  final PrepareLiquidSendUsecase _prepareLiquidSendUsecase;
  final SignBitcoinTxUsecase _signBitcoinTxUsecase;
  final SignLiquidTxUsecase _signLiquidTxUsecase;
  final BroadcastBitcoinTransactionUsecase _broadcastBitcoinTransactionUsecase;
  final BroadcastLiquidTransactionUsecase _broadcastLiquidTransactionUsecase;
  final GetNetworkFeesUsecase _getNetworkFeesUsecase;
  final CalculateLiquidAbsoluteFeesUsecase _calculateLiquidAbsoluteFeesUsecase;
  final CalculateBitcoinAbsoluteFeesUsecase
  _calculateBitcoinAbsoluteFeesUsecase;
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrencyAmountUsecase;
  final GetAddressAtIndexUsecase _getAddressAtIndexUsecase;
  final GetWalletUtxosUsecase _getWalletUtxosUsecase;
  final GetOrderUsecase _getOrderUsecase;
  final LabelsFacade _labelsFacade;
  Timer? _pollingTimer;

  Future<void> _onStarted(SellStarted event, Emitter<SellState> emit) async {
    try {
      final userSummary = await _getExchangeUserSummaryUsecase.execute();
      final settings = await _getSettingsUsecase.execute();

      emit(
        SellState.amountInput(
          userSummary: userSummary,
          bitcoinUnit: settings.bitcoinUnit,
        ),
      );
    } on GetExchangeUserSummaryException catch (e) {
      emit(SellState.initial(getUserSummaryException: e));
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
    int absoluteFees = 0;
    double exchangeRateEstimate = 0.0;

    final walletSelectionState = state.toCleanWalletSelectionState;
    if (walletSelectionState == null) {
      log.severe(
        error: 'Expected to be on SellWalletSelectionState',
        trace: StackTrace.current,
      );
      return;
    }
    emit(walletSelectionState.copyWith(isCreatingSellOrder: true, error: null));
    try {
      int requiredAmountSat;
      exchangeRateEstimate = await _convertSatsToCurrencyAmountUsecase.execute(
        currencyCode: walletSelectionState.fiatCurrency.code,
      );

      if (walletSelectionState.orderAmount.isFiat) {
        requiredAmountSat = ConvertAmount.fiatToSats(
          walletSelectionState.orderAmount.amount,
          exchangeRateEstimate,
        );
      } else {
        // The order amount is in BTC
        requiredAmountSat = ConvertAmount.btcToSats(
          walletSelectionState.orderAmount.amount,
        );
      }

      if (event.wallet.balanceSat.toInt() < requiredAmountSat) {
        emit(
          walletSelectionState.copyWith(
            error: SellError.insufficientBalance(
              requiredAmountSat: requiredAmountSat,
            ),
          ),
        );
        return;
      }

      final dummyAddressForFeeCalculation = await _getAddressAtIndexUsecase
          .execute(walletId: event.wallet.id, index: 0);

      if (event.wallet.isLiquid) {
        final pset = await _prepareLiquidSendUsecase.execute(
          walletId: event.wallet.id,
          address: dummyAddressForFeeCalculation.address,
          amountSat: requiredAmountSat,
          // 0.1 sat/vByte = 25 sat/kwu — Liquid's network minrelayfee default.
          feeRate: const RelativeFee(25),
        );
        absoluteFees = await _calculateLiquidAbsoluteFeesUsecase.execute(
          pset: pset,
        );
      } else {
        final bitcoinFees = await _getNetworkFeesUsecase.execute(
          isLiquid: false,
        );
        final fastestFee = bitcoinFees.fastest;

        final preparedSend = await _prepareBitcoinSendUsecase.execute(
          walletId: event.wallet.id,
          address: dummyAddressForFeeCalculation.address,
          amountSat: requiredAmountSat,
          networkFee: fastestFee,
        );
        absoluteFees = await _calculateBitcoinAbsoluteFeesUsecase.execute(
          psbt: preparedSend.unsignedPsbt,
        );
      }
    } catch (e) {
      emit(
        walletSelectionState.copyWith(
          error: SellError.unexpected(
            message: 'Failed to prepare transaction: $e',
          ),
        ),
      );
      return;
    }
    emit(walletSelectionState.copyWith(isCreatingSellOrder: true));
    try {
      final createdSellOrder = await _createSellOrderUsecase.execute(
        orderAmount: walletSelectionState.orderAmount,
        currency: walletSelectionState.fiatCurrency,
        network: event.wallet.isLiquid
            ? OrderBitcoinNetwork.liquid
            : OrderBitcoinNetwork.bitcoin,
      );

      if (!event.wallet.isLiquid) {
        final utxos = await _getWalletUtxosUsecase.execute(
          walletId: event.wallet.id,
        );
        emit(
          walletSelectionState.toSendPaymentState(
            selectedWallet: event.wallet,
            createdSellOrder: createdSellOrder,
            absoluteFees: absoluteFees,
            utxos: utxos,
            exchangeRateEstimate: exchangeRateEstimate,
          ),
        );
      } else {
        emit(
          walletSelectionState.toSendPaymentState(
            selectedWallet: event.wallet,
            createdSellOrder: createdSellOrder,
            absoluteFees: absoluteFees,
            exchangeRateEstimate: exchangeRateEstimate,
          ),
        );
      }
      _startPolling();
    } on PrepareLiquidSendException catch (e) {
      emit(
        walletSelectionState.copyWith(
          error: SellError.unexpected(message: e.message),
        ),
      );
    } on PrepareBitcoinSendException catch (e) {
      emit(
        walletSelectionState.copyWith(
          error: SellError.unexpected(message: e.message),
        ),
      );
    } on SellError catch (e) {
      emit(walletSelectionState.copyWith(error: e));
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
    } finally {
      if (state is SellWalletSelectionState) {
        emit(
          (state as SellWalletSelectionState).copyWith(
            isCreatingSellOrder: false,
          ),
        );
      }
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

    try {
      final createdSellOrder = await _createSellOrderUsecase.execute(
        orderAmount: walletSelectionState.orderAmount,
        currency: walletSelectionState.fiatCurrency,
        network: event.network,
      );

      // Proceed to confirmation state
      emit(
        walletSelectionState.toReceivePaymentState(
          createdSellOrder: createdSellOrder,
        ),
      );
      _startPolling();
    } on SellError catch (e) {
      emit(walletSelectionState.copyWith(error: e));
    } catch (e) {
      // Log unexpected errors
      log.severe(error: e, trace: StackTrace.current);
    } finally {
      if (state is SellWalletSelectionState) {
        emit(
          (state as SellWalletSelectionState).copyWith(
            isCreatingSellOrder: false,
          ),
        );
      }
    }
  }

  Future<void> _onOrderRefreshTimePassed(
    SellOrderRefreshTimePassed event,
    Emitter<SellState> emit,
  ) async {
    // We should be on a SellPaymentState
    final paymentState = _currentPaymentState;
    if (paymentState == null) {
      log.severe(
        error: 'Expected to be on SellPaymentState',
        trace: StackTrace.current,
      );
      return;
    }

    // Never refresh the price lock while a payment is in flight: the pending
    // transaction pays the current order's amount, and going through
    // toCleanPaymentState would clear isConfirmingPayment and visually re-arm
    // the Confirm button mid-confirmation (#2522).
    if (paymentState.isConfirmingPayment || paymentState.isPayinBroadcast) {
      return;
    }

    try {
      final refreshedOrder = await _refreshSellOrderUsecase.execute(
        orderId: paymentState.sellOrder.orderId,
      );

      // A confirmation may have started while the refresh was in flight, so
      // work from the current state instead of the snapshot above.
      final current = _currentPaymentState;
      if (current == null) return;
      if (current.isConfirmingPayment || current.isPayinBroadcast) return;
      // The error is kept: when this refresh was triggered by a failed send
      // (see _emitSendPaymentError) clearing it would erase the only
      // explanation the user has. The next confirmation clears it anyway.
      emit(current.copyWith(sellOrder: refreshedOrder));
    } on SellError catch (e) {
      // Same re-read as the success path: a refresh failure must not paint an
      // error over a confirmation that started while it was in flight.
      final current = _currentPaymentState;
      if (current == null) return;
      if (current.isConfirmingPayment || current.isPayinBroadcast) return;
      emit(current.copyWith(error: e));
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
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

    // The payin is already on the wire. Re-running prepare/sign/broadcast could
    // pay the order a second time from different UTXOs, so only wait for the
    // order to catch up (#2522).
    if (sellPaymentState.isPayinBroadcast) {
      emit(sellPaymentState.copyWith(isConfirmingPayment: true));
      try {
        await _completeAfterBroadcast(emit);
      } catch (e) {
        log.severe(error: e, trace: StackTrace.current);
      }
      return;
    }

    emit(sellPaymentState.copyWith(isConfirmingPayment: true));
    try {
      final wallet = sellPaymentState.selectedWallet;
      if (wallet == null) {
        throw const SellError.unexpected(
          message: 'No wallet selected to send payment',
        );
      }
      final isLiquid = wallet.isLiquid;
      final payinAmountSat = ConvertAmount.btcToSats(
        sellPaymentState.sellOrder.payinAmount,
      );
      if (isLiquid) {
        final pset = await _prepareLiquidSendUsecase.execute(
          walletId: wallet.id,
          address: sellPaymentState.sellOrder.liquidAddress!,
          amountSat: payinAmountSat,
          // 0.1 sat/vByte = 25 sat/kwu — Liquid's network minrelayfee default.
          feeRate: const RelativeFee(25),
        );
        final signedPset = await _signLiquidTxUsecase.execute(
          pset: pset,
          walletId: wallet.id,
        );
        // Derived before broadcasting so the latch can be set on the very next
        // line: nothing may run between the broadcast and the latch.
        final tx = await LiquidTx.fromPset(signedPset);
        final txid = tx.txid;
        await _broadcastLiquidTransactionUsecase.execute(signedPset);
        _latchBroadcast(emit, txid);
        await _labelsFacade.store(
          NewLabel.tx(
            transactionId: txid,
            label: LabelSystem.exchangeSell.label,
            origin: wallet.id,
          ),
        );
      } else {
        final absoluteFees = sellPaymentState.absoluteFees;
        if (absoluteFees == null) {
          throw const SellError.unexpected(
            message: 'Transaction fees not calculated. Please try again.',
          );
        }

        final preparedSend = await _prepareBitcoinSendUsecase.execute(
          walletId: wallet.id,
          address: sellPaymentState.sellOrder.bitcoinAddress!,
          amountSat: payinAmountSat,
          networkFee: NetworkFee.absolute(absoluteFees),
          selectedInputs: sellPaymentState.selectedUtxos.isNotEmpty
              ? sellPaymentState.selectedUtxos
              : null,
          replaceByFee: sellPaymentState.replaceByFee,
        );
        final absoluteFeesUpdated = await _calculateBitcoinAbsoluteFeesUsecase
            .execute(psbt: preparedSend.unsignedPsbt);
        emit(
          (_currentPaymentState ?? sellPaymentState).copyWith(
            absoluteFees: absoluteFeesUpdated,
          ),
        );
        final signedTx = await _signBitcoinTxUsecase.execute(
          psbt: preparedSend.unsignedPsbt,
          walletId: wallet.id,
        );
        // Derived before broadcasting so the latch can be set on the very next
        // line: nothing may run between the broadcast and the latch.
        final tx = await BitcoinTx.fromPsbt(preparedSend.unsignedPsbt);
        final txid = tx.txid;
        await _broadcastBitcoinTransactionUsecase.execute(
          signedTx.signedPsbt,
          isPsbt: true,
        );
        _latchBroadcast(emit, txid);
        await _labelsFacade.store(
          NewLabel.tx(
            transactionId: txid,
            label: LabelSystem.exchangeSell.label,
            origin: wallet.id,
          ),
        );
      }
      await _completeAfterBroadcast(emit);
    } on PrepareLiquidSendException catch (e) {
      _emitSendPaymentError(emit, SellError.unexpected(message: e.message));
    } on PrepareBitcoinSendException catch (e) {
      _emitSendPaymentError(emit, SellError.unexpected(message: e.toString()));
    } on SignLiquidTxException catch (e) {
      _emitSendPaymentError(emit, SellError.unexpected(message: e.toString()));
    } on SignBitcoinTxException catch (e) {
      // Handle SellError and emit error state
      _emitSendPaymentError(emit, SellError.unexpected(message: e.toString()));
    } catch (e) {
      // Log unexpected errors
      log.severe(error: e, trace: StackTrace.current);
      _emitSendPaymentError(emit, SellError.unexpected(message: e.toString()));
    } finally {
      final current = _currentPaymentState;
      // Once broadcast, the confirmation stays in flight until the order
      // reflects the payment; polling takes it to the success state.
      if (current != null && !current.isPayinBroadcast) {
        emit(current.copyWith(isConfirmingPayment: false));
      }
    }
  }

  SellPaymentState? get _currentPaymentState {
    final currentState = state;
    return currentState is SellPaymentState ? currentState : null;
  }

  void _latchBroadcast(Emitter<SellState> emit, String txid) {
    final current = _currentPaymentState;
    if (current == null) return;
    emit(
      current.copyWith(
        payinBroadcastTxid: txid,
        isConfirmingPayment: true,
        error: null,
      ),
    );
  }

  /// Waits for the order to reflect the broadcast payin and moves to the
  /// success state with the refreshed order (#2530).
  Future<void> _completeAfterBroadcast(Emitter<SellState> emit) async {
    // 5s delay gives backend time to register the 0 conf
    await Future.delayed(const Duration(seconds: 5));

    final paymentState = _currentPaymentState;
    if (paymentState == null) return;

    final latestOrder = await _getOrderUsecase.execute(
      orderId: paymentState.sellOrder.orderId,
    );

    if (latestOrder is! SellOrder) {
      throw const SellError.unexpected(
        message: 'Expected SellOrder but received a different order type',
      );
    }

    emit(paymentState.toSuccessState(sellOrder: latestOrder));
  }

  void _emitSendPaymentError(Emitter<SellState> emit, SellError error) {
    final current = _currentPaymentState;
    if (current == null) return;
    if (current.isPayinBroadcast) {
      // The transaction is already on the wire. Showing a retryable error here
      // would re-arm Confirm and risk a second payment (#2522), so stay in the
      // "payment sent, refreshing order" state and let polling finish the job.
      return;
    }
    emit(current.copyWith(error: error, isConfirmingPayment: false));

    // Confirm is live again, but the price-lock countdown fires onTimeout only
    // once. If the deadline elapsed during this failed attempt, the skip in
    // _onOrderRefreshTimePassed dropped that one refresh and nothing else will
    // ask for it, leaving the user retrying against a stale quote.
    if (!current.sellOrder.confirmationDeadline.isAfter(DateTime.now())) {
      add(const SellEvent.orderRefreshTimePassed());
    }
  }

  Future<void> _onPollOrderStatus(
    SellPollOrderStatus event,
    Emitter<SellState> emit,
  ) async {
    if (state is! SellPaymentState) return;

    final sellPaymentState = state as SellPaymentState;

    try {
      final latestOrder = await _getOrderUsecase.execute(
        orderId: sellPaymentState.sellOrder.orderId,
      );

      if (latestOrder is! SellOrder) {
        log.severe(
          error: 'Expected SellOrder but received a different order type',
          trace: StackTrace.current,
        );
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
        // The fetch takes seconds and the poll runs for the life of the screen,
        // so it routinely spans the broadcast. Emitting the pre-await snapshot
        // would drop the latch and re-arm Confirm (#2522), so merge into the
        // current state instead.
        final current = _currentPaymentState;
        if (current == null) return;
        emit(current.copyWith(sellOrder: latestOrder, isPolling: true));
      }
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
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

    try {
      final utxos = await _getWalletUtxosUsecase.execute(walletId: wallet.id);
      emit((_currentPaymentState ?? sellPaymentState).copyWith(utxos: utxos));
    } catch (e) {
      emit(
        (_currentPaymentState ?? sellPaymentState).copyWith(
          error: SellError.unexpected(message: 'Failed to load UTXOs: $e'),
        ),
      );
    }
  }

  Future<void> _recalculateFees(Emitter<SellState> emit) async {
    if (state is! SellPaymentState) return;

    final sellPaymentState = state as SellPaymentState;
    final wallet = sellPaymentState.selectedWallet;
    if (wallet == null) return;

    try {
      final payinAmountSat = ConvertAmount.btcToSats(
        sellPaymentState.sellOrder.payinAmount,
      );

      if (wallet.isLiquid) {
        final dummyAddressForFeeCalculation = await _getAddressAtIndexUsecase
            .execute(walletId: wallet.id, index: 0);
        final pset = await _prepareLiquidSendUsecase.execute(
          walletId: wallet.id,
          address: dummyAddressForFeeCalculation.address,
          amountSat: payinAmountSat,
          // 0.1 sat/vByte = 25 sat/kwu — Liquid's network minrelayfee default.
          feeRate: const RelativeFee(25),
        );
        final absoluteFees = await _calculateLiquidAbsoluteFeesUsecase.execute(
          pset: pset,
        );
        emit(
          (_currentPaymentState ?? sellPaymentState).copyWith(
            absoluteFees: absoluteFees,
          ),
        );
      } else {
        final bitcoinFees = await _getNetworkFeesUsecase.execute(
          isLiquid: false,
        );
        final fastestFee = bitcoinFees.fastest;

        final dummyAddressForFeeCalculation = await _getAddressAtIndexUsecase
            .execute(walletId: wallet.id, index: 0);
        final preparedSend = await _prepareBitcoinSendUsecase.execute(
          walletId: wallet.id,
          address: dummyAddressForFeeCalculation.address,
          amountSat: payinAmountSat,
          networkFee: fastestFee,
          selectedInputs: sellPaymentState.selectedUtxos.isNotEmpty
              ? sellPaymentState.selectedUtxos
              : null,
          replaceByFee: sellPaymentState.replaceByFee,
        );
        final absoluteFees = await _calculateBitcoinAbsoluteFeesUsecase.execute(
          psbt: preparedSend.unsignedPsbt,
        );
        emit(
          (_currentPaymentState ?? sellPaymentState).copyWith(
            absoluteFees: absoluteFees,
          ),
        );
      }
    } catch (e) {
      emit(
        (_currentPaymentState ?? sellPaymentState).copyWith(
          error: SellError.unexpected(
            message: 'Failed to recalculate fees: $e',
          ),
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _stopPolling();
    return super.close();
  }
}
