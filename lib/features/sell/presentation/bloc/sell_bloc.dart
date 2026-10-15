import 'dart:async';

import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/core/fees/domain/fee_preview_cache.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bull_logger/bull_logger.dart' show log;
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart' hide Network;
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/sell/domain/label_completed_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/create_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/refresh_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/get_payjoin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/watch_payjoin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/broadcast_sell_payin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/calculate_sell_liquid_fees_usecase.dart';
import 'package:bb_mobile/features/sell/domain/load_sell_context_usecase.dart';
import 'package:bb_mobile/features/sell/domain/prepare_sell_bitcoin_payin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/read_sell_payin_txid_usecase.dart';
import 'package:bb_mobile/core/widgets/fees/fee_modal_controller.dart';
import 'package:bb_mobile/features/sell/domain/load_sell_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/sell/domain/prepare_sell_liquid_payin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_presets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sign_sell_payin_usecase.dart';
import 'package:bip21_uri/bip21_uri.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_payjoin/bull_payjoin.dart'
    show PayjoinSenderSession, PayjoinSession, PayjoinSessionWindow;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sell_bloc.freezed.dart';
part 'sell_event.dart';
part 'sell_state.dart';

class SellBloc extends Bloc<SellEvent, SellState>
    implements FeeModalActions, FeeModalViewState {
  SellBloc({
    required this._loadSellContextUsecase,
    required this._createSellOrderUsecase,
    required this._refreshSellOrderUsecase,
    required this._prepareSellBitcoinPayinUsecase,
    required this._prepareSellLiquidPayinUsecase,
    required this._signSellPayinUsecase,
    required this._broadcastSellPayinUsecase,
    required this._sendWithPayjoinUsecase,
    required this._watchPayjoinUsecase,
    required this._getPayjoinUsecase,
    required this._calculateSellLiquidFeesUsecase,
    required this._loadSellWalletUtxosUsecase,
    required this._readSellPayinTxidUsecase,
    required this._labelsFacade,
    required this._labelCompletedSellOrderUsecase,
    required this._previewBitcoinFeeUsecase,
    required this._previewBitcoinFeePresetsUsecase,
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
    on<SellPayjoinToggled>(_onPayjoinToggled);
    on<SellPayjoinSessionUpdated>(_onPayjoinSessionUpdated);
    on<SellReplaceByFeeChanged>(_onReplaceByFeeChanged);
    on<SellUtxosSelected>(_onUtxosSelected);
    on<SellLoadUtxos>(_onLoadUtxos);
    on<SellFeeOptionSelected>(_onFeeOptionSelected);
    on<SellCustomFeeChanged>(_onCustomFeeChanged);
    on<SellCustomFeeArmed>(_onCustomFeeArmed);
    on<SellCustomFeeDisarmed>(_onCustomFeeDisarmed);
    on<SellCustomFeeFinalized>(_onCustomFeeFinalized);
    on<SellCustomFeePreviewRequested>(_onCustomFeePreviewRequested);
    on<SellPresetFeesPreviewRequested>(_onPresetFeesPreviewRequested);
  }

  final LoadSellContextUsecase _loadSellContextUsecase;
  final CreateSellOrderUsecase _createSellOrderUsecase;
  final RefreshSellOrderUsecase _refreshSellOrderUsecase;
  final PrepareSellBitcoinPayinUsecase _prepareSellBitcoinPayinUsecase;
  final PrepareSellLiquidPayinUsecase _prepareSellLiquidPayinUsecase;
  final SignSellPayinUsecase _signSellPayinUsecase;
  final BroadcastSellPayinUsecase _broadcastSellPayinUsecase;
  final SendWithPayjoinUsecase _sendWithPayjoinUsecase;
  final WatchPayjoinUsecase _watchPayjoinUsecase;
  final GetPayjoinUsecase _getPayjoinUsecase;
  final CalculateSellLiquidFeesUsecase _calculateSellLiquidFeesUsecase;
  final LoadSellWalletUtxosUsecase _loadSellWalletUtxosUsecase;
  final ReadSellPayinTxidUsecase _readSellPayinTxidUsecase;
  final LabelsFacade _labelsFacade;
  final LabelCompletedSellOrderUsecase _labelCompletedSellOrderUsecase;
  final PreviewBitcoinFeeUsecase _previewBitcoinFeeUsecase;
  final PreviewBitcoinFeePresetsUsecase _previewBitcoinFeePresetsUsecase;
  Timer? _pollingTimer;
  StreamSubscription<Result<PayjoinSession, SellFailure>>? _payjoinSubscription;
  String? _activePayjoinSessionId;

  /// The order the active payjoin session pays for. A session resolution is
  /// only allowed to latch/complete the payment state while this still
  /// matches the current order — otherwise the session belongs to a
  /// torn-down order and must not mark the new one as paid.
  String? _activePayjoinOrderId;

  /// A payment is committed once its transaction is on the wire
  /// (`isPayinBroadcast`), while it is being prepared/signed/broadcast
  /// (`isConfirmingPayment`), and for the whole payjoin negotiation (the
  /// session owns the eventual broadcast). Tearing down the payment state
  /// in any of those windows can pay an order twice.
  bool get _hasPaymentInFlight {
    final current = _currentPaymentState;
    return _activePayjoinSessionId != null ||
        (current != null &&
            (current.isConfirmingPayment || current.isPayinBroadcast));
  }

  /// Bumped whenever the cached previews stop describing the payin being
  /// built (typed rate, coin selection, RBF, a refreshed payin amount). A
  /// preview build that started under an older epoch is discarded on return
  /// instead of writing a slot for a tx shape that no longer exists.
  int _bitcoinPreviewEpoch = 0;

  Future<void> _onStarted(SellStarted event, Emitter<SellState> emit) async {
    final contextResult = await _loadSellContextUsecase
        .userSummaryAndSettings();
    switch (contextResult) {
      case Err():
        // Already logged at the boundary. `initial` is the shared shape the
        // exchange screens read, so the summary simply stays absent.
        emit(const SellState.initial());
      case Ok(:final value):
        final userSummary = value.userSummary;
        final settings = value.settings;
        emit(
          SellState.amountInput(
            userSummary: userSummary,
            bitcoinUnit: settings.bitcoinUnit,
          ),
        );
    }
  }

  Future<void> _onAmountInputContinuePressed(
    SellAmountInputContinuePressed event,
    Emitter<SellState> emit,
  ) async {
    // Never tear down a payment in flight: going back to the amount input
    // drops the payment state, and the payjoin session of the current order
    // would keep negotiating orphaned — its resolution could then latch onto
    // a later order's payment state.
    if (_hasPaymentInFlight) return;

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
    // Never tear down a payment in flight to start a new order: the pending
    // transaction pays the CURRENT order, and a new order built on top of an
    // active payjoin session inherits its resolution (cross-order latch —
    // the new order would show a success screen without ever being paid).
    if (_hasPaymentInFlight) return;

    int absoluteFees = 0;
    double exchangeRateEstimate = 0.0;
    // Carried into the payment state so the confirmation screen can offer the
    // fee modal (#2521): it needs the presets to price the tiles and a vsize
    // to check an absolute custom fee against the relay floor.
    FeeOptions? bitcoinFees;
    int? bitcoinTxSize;
    // This builds a brand-new payment state, with its own order, wallet and
    // empty preview cache. A preview still in flight for the previous one would
    // otherwise land in that cache and price this payin with the last order's
    // fees.
    _bitcoinPreviewEpoch++;

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
      final rateResult = await _loadSellContextUsecase.satsToCurrency(
        currencyCode: walletSelectionState.fiatCurrency.code,
      );
      switch (rateResult) {
        case Ok(:final value):
          exchangeRateEstimate = value;
        case Err(:final failure):
          emit(walletSelectionState.copyWith(error: failure));
          return;
      }

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
            error: SellInsufficientBalanceFailure(
              requiredAmountSat: requiredAmountSat,
            ),
          ),
        );
        return;
      }

      final addressResult = await _loadSellContextUsecase.addressAtIndex(
        walletId: event.wallet.id,
        index: 0,
      );
      final WalletAddress dummyAddressForFeeCalculation;
      switch (addressResult) {
        case Ok(:final value):
          dummyAddressForFeeCalculation = value;
        case Err(:final failure):
          emit(walletSelectionState.copyWith(error: failure));
          return;
      }

      if (event.wallet.isLiquid) {
        final psetResult = await _prepareSellLiquidPayinUsecase.execute(
          walletId: event.wallet.id,
          address: dummyAddressForFeeCalculation.address,
          amountSat: requiredAmountSat,
          // 0.1 sat/vByte = 25 sat/kwu — Liquid's network minrelayfee default.
          feeRate: const RelativeFee(25),
        );
        final String pset;
        switch (psetResult) {
          case Ok(:final value):
            pset = value;
          case Err(:final failure):
            emit(walletSelectionState.copyWith(error: failure));
            return;
        }
        final feesResult = await _calculateSellLiquidFeesUsecase.execute(
          pset: pset,
        );
        switch (feesResult) {
          case Ok(:final value):
            absoluteFees = value;
          case Err(:final failure):
            emit(walletSelectionState.copyWith(error: failure));
            return;
        }
      } else {
        final feeOptions = await _loadSellContextUsecase.networkFees(
          isLiquid: false,
        );
        switch (feeOptions) {
          case Ok(:final value):
            bitcoinFees = value;
          case Err(:final failure):
            emit(walletSelectionState.copyWith(error: failure));
            return;
        }
        // Fastest is the default selection, so the estimate shown on arrival
        // is the estimate for the tier the payin would be built at.
        final preparedResult = await _prepareSellBitcoinPayinUsecase.execute(
          walletId: event.wallet.id,
          address: dummyAddressForFeeCalculation.address,
          amountSat: requiredAmountSat,
          networkFee: bitcoinFees.fastest,
        );
        final PreparedSellBitcoinPayin preparedSend;
        switch (preparedResult) {
          case Ok(:final value):
            preparedSend = value;
          case Err(:final failure):
            emit(walletSelectionState.copyWith(error: failure));
            return;
        }
        bitcoinTxSize = preparedSend.txSize;
        absoluteFees = preparedSend.absoluteFees;
      }
    } catch (e, st) {
      // Boundary onto the shared prepare/fee use-cases, which still throw.
      log.severe(
        message: 'Failed to prepare the sell payin',
        error: e,
        trace: st,
      );
      emit(
        walletSelectionState.copyWith(
          error: SellUnexpectedFailure('Failed to prepare transaction: $e'),
        ),
      );
      return;
    }
    emit(walletSelectionState.copyWith(isCreatingSellOrder: true));
    try {
      final orderResult = await _createSellOrderUsecase.execute(
        orderAmount: walletSelectionState.orderAmount,
        currency: walletSelectionState.fiatCurrency,
        network: event.wallet.isLiquid
            ? OrderBitcoinNetwork.liquid
            : OrderBitcoinNetwork.bitcoin,
        // Asking for payjoin only makes the exchange publish a bip21URI on the
        // order; whether the payin actually uses it is decided at confirmation
        // time. So requesting it here costs nothing when the payment ends up
        // being an ordinary one — the exchange credits a plain transaction to
        // the same address either way.
        usePayjoin:
            !event.wallet.isLiquid &&
            walletSelectionState.userSummary.payjoinReceiveEnabled,
      );
      final SellOrder createdSellOrder;
      switch (orderResult) {
        case Ok(:final value):
          createdSellOrder = value;
        case Err(:final failure):
          emit(
            walletSelectionState.copyWith(
              isCreatingSellOrder: false,
              error: failure,
            ),
          );
          return;
      }

      if (!event.wallet.isLiquid) {
        final utxosResult = await _loadSellWalletUtxosUsecase.execute(
          walletId: event.wallet.id,
        );
        final List<WalletUtxo> utxos;
        switch (utxosResult) {
          case Ok(:final value):
            utxos = value;
          case Err(:final failure):
            emit(walletSelectionState.copyWith(error: failure));
            return;
        }
        emit(
          walletSelectionState.toSendPaymentState(
            selectedWallet: event.wallet,
            createdSellOrder: createdSellOrder,
            absoluteFees: absoluteFees,
            utxos: utxos,
            exchangeRateEstimate: exchangeRateEstimate,
            bitcoinFees: bitcoinFees,
            bitcoinTxSize: bitcoinTxSize,
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
    } catch (e, st) {
      log.severe(
        message: 'Unexpected error while selecting the sell wallet',
        error: e,
        trace: st,
      );
      emit(walletSelectionState.copyWith(error: SellUnexpectedFailure('$e')));
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
    // Same guard as _onWalletSelected: switching the network rebuilds the
    // order, which must never happen while a payment is in flight.
    if (_hasPaymentInFlight) return;

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
      final orderResult = await _createSellOrderUsecase.execute(
        orderAmount: walletSelectionState.orderAmount,
        currency: walletSelectionState.fiatCurrency,
        network: event.network,
      );
      final SellOrder createdSellOrder;
      switch (orderResult) {
        case Ok(:final value):
          createdSellOrder = value;
        case Err(:final failure):
          emit(
            walletSelectionState.copyWith(
              isCreatingSellOrder: false,
              error: failure,
            ),
          );
          return;
      }

      // Proceed to confirmation state
      emit(
        walletSelectionState.toReceivePaymentState(
          createdSellOrder: createdSellOrder,
        ),
      );
      _startPolling();
    } catch (e, st) {
      log.severe(
        message: 'Unexpected error while creating the sell order',
        error: e,
        trace: st,
      );
      emit(walletSelectionState.copyWith(error: SellUnexpectedFailure('$e')));
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
      final refreshResult = await _refreshSellOrderUsecase.execute(
        orderId: paymentState.sellOrder.orderId,
        expectedDepositAddress: paymentState.sellOrder.toAddress,
      );
      final SellOrder refreshedOrder;
      switch (refreshResult) {
        case Ok(:final value):
          refreshedOrder = value;
        case Err(:final failure):
          // Same re-read as the success path: a refresh failure must not paint
          // an error over a confirmation that started while it was in flight.
          final currentOnFailure = _currentPaymentState;
          if (currentOnFailure == null) return;
          if (currentOnFailure.isConfirmingPayment ||
              currentOnFailure.isPayinBroadcast) {
            return;
          }
          emit(currentOnFailure.copyWith(error: failure));
          return;
      }

      // A confirmation may have started while the refresh was in flight, so
      // work from the current state instead of the snapshot above.
      final current = _currentPaymentState;
      if (current == null) return;
      if (current.isConfirmingPayment || current.isPayinBroadcast) return;
      // The error is kept: when this refresh was triggered by a failed send
      // (see _emitSendPaymentError) clearing it would erase the only
      // explanation the user has. The next confirmation clears it anyway.
      final refreshed = current.copyWith(sellOrder: refreshedOrder);
      // A new price lock moves the payin amount, which invalidates every
      // preview built for the old one.
      emit(
        refreshedOrder.payinAmount == current.sellOrder.payinAmount
            ? refreshed
            : _clearedFeePreviews(refreshed),
      );
    } catch (e, st) {
      log.severe(
        message: 'Unexpected error while refreshing the sell order',
        error: e,
        trace: st,
      );
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

    // Second half of that same latch, for the payjoin path: the txid only lands
    // once the session resolves, so until then the *session* is what says this
    // order's payin is already committed.
    if (_activePayjoinSessionId != null) {
      emit(sellPaymentState.copyWith(isConfirmingPayment: true));
      return;
    }

    emit(sellPaymentState.copyWith(isConfirmingPayment: true));
    var waitingForPayjoin = false;
    try {
      final wallet = sellPaymentState.selectedWallet;
      if (wallet == null) {
        _emitSendPaymentError(
          emit,
          const SellUnexpectedFailure('No wallet selected to send payment'),
        );
        return;
      }
      final isLiquid = wallet.isLiquid;
      final payinAmountSat = ConvertAmount.btcToSats(
        sellPaymentState.sellOrder.payinAmount,
      );
      if (isLiquid) {
        final psetResult = await _prepareSellLiquidPayinUsecase.execute(
          walletId: wallet.id,
          address: sellPaymentState.sellOrder.liquidAddress!,
          amountSat: payinAmountSat,
          // 0.1 sat/vByte = 25 sat/kwu — Liquid's network minrelayfee default.
          feeRate: const RelativeFee(25),
        );
        final String pset;
        switch (psetResult) {
          case Ok(:final value):
            pset = value;
          case Err(:final failure):
            _emitSendPaymentError(emit, failure);
            return;
        }
        final signedResult = await _signSellPayinUsecase.liquid(
          pset: pset,
          walletId: wallet.id,
        );
        final String signedPset;
        switch (signedResult) {
          case Ok(:final value):
            signedPset = value;
          case Err(:final failure):
            _emitSendPaymentError(emit, failure);
            return;
        }
        // Derived before broadcasting so the latch can be set on the very next
        // line: nothing may run between the broadcast and the latch.
        final txidResult = await _readSellPayinTxidUsecase.fromPset(signedPset);
        final String txid;
        switch (txidResult) {
          case Ok(:final value):
            txid = value;
          case Err(:final failure):
            _emitSendPaymentError(emit, failure);
            return;
        }
        final broadcast = await _broadcastSellPayinUsecase.liquid(signedPset);
        if (broadcast case Err(:final failure)) {
          _emitSendPaymentError(emit, failure);
          return;
        }
        _latchBroadcast(emit, txid);
        await _labelsFacade.store(
          NewLabel.tx(
            transactionId: txid,
            label: LabelSystem.exchangeSell.label,
            origin: wallet.id,
          ),
        );
      } else {
        // The rate the user committed in the fee modal, which defaults to
        // Fastest. The absolute fee from the last estimate is the fallback for
        // the case where the presets went missing — being unable to pick a fee
        // must not block paying the order.
        final absoluteFees = sellPaymentState.absoluteFees;
        final networkFee =
            sellPaymentState.selectedFee ??
            (absoluteFees != null ? NetworkFee.absolute(absoluteFees) : null);
        if (networkFee == null) {
          _emitSendPaymentError(
            emit,
            const SellFeesUnavailableFailure(
              'no network fee selected or calculated for the payin',
            ),
          );
          return;
        }

        final preparedResult = await _prepareSellBitcoinPayinUsecase.execute(
          walletId: wallet.id,
          address: sellPaymentState.sellOrder.bitcoinAddress!,
          amountSat: payinAmountSat,
          networkFee: networkFee,
          selectedInputs: sellPaymentState.selectedUtxos.isNotEmpty
              ? sellPaymentState.selectedUtxos
              : null,
          replaceByFee: sellPaymentState.replaceByFee,
        );
        final PreparedSellBitcoinPayin preparedSend;
        switch (preparedResult) {
          case Ok(:final value):
            preparedSend = value;
          case Err(:final failure):
            _emitSendPaymentError(emit, failure);
            return;
        }
        final absoluteFeesUpdated = preparedSend.absoluteFees;
        // An absolute custom fee was checked against the *previous* vsize; if
        // this build came out larger it can sit below the relay floor, which
        // strands the payin unbroadcastable. Re-check the built fee against the
        // built vsize before signing rather than trusting BDK to refuse.
        if (!NetworkFee.absolute(absoluteFeesUpdated).aboveMinRelay(
          txSize: preparedSend.txSize,
          floorSatPerKwu: sellPaymentState.bitcoinFees?.minRelay.satPerKwu,
        )) {
          _emitSendPaymentError(
            emit,
            const SellFeeBelowRelayFloorFailure(
              'Built fee is below the network relay minimum',
            ),
          );
          return;
        }
        emit(
          (_currentPaymentState ?? sellPaymentState).copyWith(
            absoluteFees: absoluteFeesUpdated,
            bitcoinTxSize: preparedSend.txSize,
          ),
        );

        // The exchange published a payjoin endpoint for this order, and there is
        // still enough of the order's window left for a negotiation to finish.
        // The window is bounded by the order, never by the user's global session
        // setting: a payjoin that outlived the order would land the payin
        // against a dead order.
        final payjoinBip21 = sellPaymentState.sellOrder.bip21URI;
        final confirmationDeadline =
            sellPaymentState.sellOrder.confirmationDeadline;
        final payjoinWindow =
            payjoinBip21 == null || confirmationDeadline == null
            ? null
            : PayjoinSessionWindow.forOrderDeadline(confirmationDeadline);
        log.info(
          'Sell Payjoin confirmation: '
          'toggle=${sellPaymentState.isPayjoinEnabled}, '
          'bip21Present=${payjoinBip21 != null}, '
          'windowSec=${payjoinWindow ?? 0}',
        );

        if (sellPaymentState.isPayjoinEnabled &&
            payjoinBip21 != null &&
            payjoinWindow != null) {
          log.info('Sell Payjoin sender creation started');
          final payjoinResult = await _sendWithPayjoinUsecase.execute(
            walletId: wallet.id,
            isTestnet: wallet.network.isTestnet,
            bip21: payjoinBip21,
            unsignedOriginalPsbt: preparedSend.unsignedPsbt,
            amountSat: payinAmountSat,
            networkFeesSatPerVb: networkFee.isRelative
                ? networkFee.value as double
                : absoluteFeesUpdated / preparedSend.txSize,
            expireAfterSec: payjoinWindow.inSeconds,
          );
          final PayjoinSenderSession payjoinSender;
          switch (payjoinResult) {
            case Ok(:final value):
              payjoinSender = value;
            case Err(:final failure):
              // A failed start is not a failed payment: the engine persists
              // the session — signed original included — BEFORE posting to the
              // directory, and a post failure keeps the row so the expiry
              // fallback still settles the payment. Surfacing an error here
              // and re-arming Confirm would let a plain retry pay this order a
              // second time on disjoint inputs (the persisted session's inputs
              // are reserved out of coin selection, so the two transactions
              // cannot conflict). When the row exists, adopt the session and
              // proceed exactly as a successful start; only a start that left
              // nothing behind may fall through to the error path.
              final PayjoinSession? persisted;
              switch (await _getPayjoinUsecase.execute(payjoinBip21)) {
                case Ok(:final value):
                  persisted = value;
                case Err():
                  persisted = null;
              }
              if (persisted is! PayjoinSenderSession) {
                // Nothing was committed, so re-arming Confirm is safe.
                _emitSendPaymentError(emit, failure);
                return;
              }
              log.warning(
                'Sell Payjoin start failed but session ${persisted.logRef} is '
                'persisted (status=${persisted.status.name}); adopting it '
                'instead of re-arming Confirm',
              );
              payjoinSender = persisted;
          }
          log.info(
            'Sell Payjoin sender active: ${payjoinSender.logRef}, '
            'status=${payjoinSender.status.name}',
          );
          // The session owns eventual broadcast of either the proposal or the
          // original transaction, and neither is on the wire yet. Watch it
          // instead of latching a txid now: announcing success here showed a
          // settled sale for a payin that may still fail. Re-entering Confirm
          // would create a second session against different UTXOs, which the
          // guard above prevents while this one runs.
          _watchPayjoin(
            payjoinSender.id,
            orderId: sellPaymentState.sellOrder.orderId,
          );
          waitingForPayjoin = true;
          // The original transaction is what reaches the chain whenever the
          // negotiation does not complete, and the payjoin repository labels the
          // payjoin transaction itself once it does.
          await _labelsFacade.store(
            NewLabel.tx(
              transactionId: payjoinSender.originalTxId,
              label: LabelSystem.exchangeSell.label,
              origin: wallet.id,
            ),
          );
        } else {
          log.info(
            'Sell Payjoin skipped; broadcasting plain transaction: '
            'toggle=${sellPaymentState.isPayjoinEnabled}, '
            'bip21Present=${payjoinBip21 != null}, '
            'windowAvailable=${payjoinWindow != null}',
          );
          final signedResult = await _signSellPayinUsecase.bitcoin(
            psbt: preparedSend.unsignedPsbt,
            walletId: wallet.id,
          );
          final ({String signedPsbt, int txSize}) signedTx;
          switch (signedResult) {
            case Ok(:final value):
              signedTx = value;
            case Err(:final failure):
              _emitSendPaymentError(emit, failure);
              return;
          }
          // Derived before broadcasting so the latch can be set on the very next
          // line: nothing may run between the broadcast and the latch.
          final txidResult = await _readSellPayinTxidUsecase.fromPsbt(
            preparedSend.unsignedPsbt,
          );
          final String txid;
          switch (txidResult) {
            case Ok(:final value):
              txid = value;
            case Err(:final failure):
              _emitSendPaymentError(emit, failure);
              return;
          }
          final broadcast = await _broadcastSellPayinUsecase.bitcoin(
            signedTx.signedPsbt,
            isPsbt: true,
          );
          if (broadcast case Err(:final failure)) {
            _emitSendPaymentError(emit, failure);
            return;
          }
          _latchBroadcast(emit, txid);
          await _labelsFacade.store(
            NewLabel.tx(
              transactionId: txid,
              label: LabelSystem.exchangeSell.label,
              origin: wallet.id,
            ),
          );
        }
      }
      if (!waitingForPayjoin) await _completeAfterBroadcast(emit);
    } catch (e, st) {
      log.severe(
        message: 'Unexpected error while confirming the sell payin',
        error: e,
        trace: st,
      );
      _emitSendPaymentError(emit, SellUnexpectedFailure(e.toString()));
    } finally {
      final current = _currentPaymentState;
      // Once broadcast, the confirmation stays in flight until the order
      // reflects the payment; polling takes it to the success state. A payjoin
      // session still negotiating counts as committed for the same reason.
      if (current != null &&
          !current.isPayinBroadcast &&
          _activePayjoinSessionId == null) {
        emit(current.copyWith(isConfirmingPayment: false));
      }
    }
  }

  void _watchPayjoin(String sessionId, {required String orderId}) {
    _activePayjoinSessionId = sessionId;
    _activePayjoinOrderId = orderId;
    unawaited(_payjoinSubscription?.cancel());
    var reArmed = false;
    void retryLater() {
      // The session owns eventual broadcast of the proposal or the original,
      // so a dead watcher would leave a sale that actually settles looking
      // stuck. Re-arm once: the stream stays alive across a failed update, so
      // re-arming per update would cancel and rebuild a healthy subscription
      // every five seconds.
      if (reArmed) return;
      reArmed = true;
      Future<void>.delayed(const Duration(seconds: 5), () {
        if (!isClosed && _activePayjoinSessionId == sessionId) {
          _watchPayjoin(sessionId, orderId: orderId);
        }
      });
    }

    _payjoinSubscription = _watchPayjoinUsecase
        .execute(sessionId)
        .listen(
          (result) {
            switch (result) {
              case Ok(:final value):
                add(SellEvent.payjoinSessionUpdated(value));
              case Err():
                // Already logged at the boundary with its type and reason.
                retryLater();
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            log.warning(
              'Payjoin session watch failed',
              error: error,
              trace: stackTrace,
            );
            retryLater();
          },
          onDone: retryLater,
        );
  }

  Future<void> _onPayjoinSessionUpdated(
    SellPayjoinSessionUpdated event,
    Emitter<SellState> emit,
  ) async {
    final session = event.session;
    if (session.id != _activePayjoinSessionId || session.isOngoing) return;

    // `expired` is terminal but settles nothing: the package released this
    // session's inputs and stopped re-broadcasting it, so the user may confirm
    // again — which the released latch below allows.
    final subscription = _payjoinSubscription;
    _payjoinSubscription = null;
    _activePayjoinSessionId = null;
    final sessionOrderId = _activePayjoinOrderId;
    _activePayjoinOrderId = null;
    await subscription?.cancel();
    final current = _currentPaymentState;
    if (current == null) return;

    // The session must belong to the order currently on screen. If the
    // payment state was torn down and rebuilt around it (a guard bypass, a
    // state reset), its resolution belongs to the OLD order: latching its
    // txid here would mark the NEW order paid without a sat moving for it.
    if (current.sellOrder.orderId != sessionOrderId) {
      log.severe(
        error:
            'Resolved Payjoin session belongs to a different order; ignoring',
        trace: StackTrace.current,
      );
      return;
    }

    if (session.isExpired) {
      emit(current.copyWith(isConfirmingPayment: false));
      return;
    }

    final txid = session.isCompleted
        ? session.txId ?? session.originalTxId
        : session.originalTxId;
    if (txid == null) {
      log.severe(
        error: 'Resolved Payjoin has no transaction id',
        trace: StackTrace.current,
      );
      return;
    }

    _latchBroadcast(emit, txid);
    try {
      await _completeAfterBroadcast(emit);
    } catch (error) {
      log.severe(error: error, trace: StackTrace.current);
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

    final orderResult = await _loadSellContextUsecase.order(
      orderId: paymentState.sellOrder.orderId,
    );
    final Order latestOrder;
    switch (orderResult) {
      case Ok(:final value):
        latestOrder = value;
      case Err():
        return;
    }

    if (latestOrder is! SellOrder) {
      log.severe(
        error: 'Expected SellOrder but received ${latestOrder.runtimeType}',
        trace: StackTrace.current,
      );
      return;
    }

    // Success requires the exchange to actually see the payin — the same
    // gate the periodic order poll applies. Five seconds is not always
    // enough for the backend to register the 0-conf; in that case stay in
    // the confirming state and let the poll take the order to success when
    // the payment shows up, rather than celebrating an order the exchange
    // has never seen paid.
    final payinStatus = latestOrder.payinStatus;
    if (payinStatus != OrderPayinStatus.inProgress &&
        payinStatus != OrderPayinStatus.awaitingConfirmation &&
        payinStatus != OrderPayinStatus.completed) {
      return;
    }

    await _labelPayjoinSellTransaction(
      latestOrder,
      paymentState.selectedWallet?.id,
    );
    emit(paymentState.toSuccessState(sellOrder: latestOrder));
  }

  void _emitSendPaymentError(Emitter<SellState> emit, SellFailure error) {
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
    final confirmationDeadline = current.sellOrder.confirmationDeadline;
    if (confirmationDeadline != null &&
        !confirmationDeadline.isAfter(DateTime.now())) {
      add(const SellEvent.orderRefreshTimePassed());
    }
  }

  void _onPayjoinToggled(SellPayjoinToggled event, Emitter<SellState> emit) {
    final paymentState = _currentPaymentState;
    if (paymentState == null || paymentState.selectedWallet?.isLiquid == true) {
      return;
    }
    if (paymentState.isConfirmingPayment || paymentState.isPayinBroadcast) {
      return;
    }
    emit(paymentState.copyWith(isPayjoinEnabled: event.enabled));
  }

  Future<void> _onPollOrderStatus(
    SellPollOrderStatus event,
    Emitter<SellState> emit,
  ) async {
    if (state is SellSuccessState) {
      final sellSuccessState = state as SellSuccessState;
      try {
        final orderResult = await _loadSellContextUsecase.order(
          orderId: sellSuccessState.sellOrder.orderId,
        );
        final Order latestOrder;
        switch (orderResult) {
          case Ok(:final value):
            latestOrder = value;
          case Err():
            return;
        }
        if (latestOrder is! SellOrder) {
          log.severe(
            error: 'Expected SellOrder but received a different order type',
            trace: StackTrace.current,
          );
          return;
        }
        await _labelPayjoinSellTransaction(latestOrder, null);
        // The explicit order-completion event is the only legitimate writer
        // of privileged exchange labels.
        // Labelling is cosmetic: the failure is logged at the boundary and
        // deliberately dropped here, so it cannot stop a completed sale from
        // reaching the success screen.
        final labelled = await _labelCompletedSellOrderUsecase.execute(
          order: latestOrder,
        );
        if (labelled case Err()) {
          log.info('Sell order completed without privileged labels');
        }
        if (!latestOrder.payjoinOutcome.isOngoing) _stopPolling();
        emit(sellSuccessState.copyWith(sellOrder: latestOrder));
      } catch (e) {
        log.severe(error: e, trace: StackTrace.current);
      }
      return;
    }
    final sellPaymentState = _currentPaymentState;
    if (sellPaymentState == null) return;

    try {
      final orderResult = await _loadSellContextUsecase.order(
        orderId: sellPaymentState.sellOrder.orderId,
      );
      final Order latestOrder;
      switch (orderResult) {
        case Ok(:final value):
          latestOrder = value;
        case Err():
          return;
      }

      if (latestOrder is! SellOrder) {
        log.severe(
          error: 'Expected SellOrder but received a different order type',
          trace: StackTrace.current,
        );
        return;
      }

      final current = _currentPaymentState;
      if (current == null) return;
      if (!current.isPayinBroadcast) {
        // Fail closed: the polled order must still pay the address the user
        // confirmed, or polling stops and the order is refused.
        final deposit = validateSellOrderDepositAddress(
          order: latestOrder,
          expectedDepositAddress: current.sellOrder.toAddress,
        );
        if (deposit case Err(:final failure)) {
          log.severe(
            message: 'Polled sell order changed its deposit address',
            error: failure.logMessage ?? failure.runtimeType.toString(),
            trace: StackTrace.current,
          );
          _stopPolling();
          emit(current.copyWith(error: failure, isPolling: false));
          return;
        }
      }

      final payinStatus = latestOrder.payinStatus;

      if (payinStatus == OrderPayinStatus.inProgress ||
          payinStatus == OrderPayinStatus.awaitingConfirmation ||
          payinStatus == OrderPayinStatus.completed) {
        _stopPolling();
        await _labelPayjoinSellTransaction(
          latestOrder,
          current.selectedWallet?.id,
        );
        emit(
          current
              .copyWith(sellOrder: latestOrder, isPolling: false)
              .toSuccessState(sellOrder: latestOrder),
        );
      } else {
        // The fetch takes seconds and the poll runs for the life of the screen,
        // so it routinely spans the broadcast. Emitting the pre-await snapshot
        // would drop the latch and re-arm Confirm (#2522), so merge into the
        // current state instead.
        emit(current.copyWith(sellOrder: latestOrder, isPolling: true));
      }
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
    }
  }

  /// The original transaction keeps its label for a plain-send fallback. Once
  /// the exchange reports a completed payjoin, tag its final transaction too.
  /// The payjoin repository supplies the separate `payjoin` system label.
  Future<void> _labelPayjoinSellTransaction(
    SellOrder order,
    String? walletId,
  ) async {
    final payjoinTxId = order.payjoin?.txid;
    if (payjoinTxId == null) return;

    await _labelsFacade.store(
      NewLabel.tx(
        transactionId: payjoinTxId,
        label: LabelSystem.exchangeSell.label,
        origin: walletId,
      ),
    );
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
    final sellPaymentState = _feeEditablePaymentState;
    if (sellPaymentState == null) return;
    // RBF changes the sequence numbers, so every cached preview PSBT is for a
    // different transaction now.
    emit(
      _clearedFeePreviews(
        sellPaymentState.copyWith(replaceByFee: event.replaceByFee),
      ),
    );
    await _recalculateFees(emit);
  }

  Future<void> _onUtxosSelected(
    SellUtxosSelected event,
    Emitter<SellState> emit,
  ) async {
    final sellPaymentState = _feeEditablePaymentState;
    if (sellPaymentState == null) return;
    final selectedUtxos = event.utxos;

    // Coin selection changed — the previews were priced on the old input set.
    emit(
      _clearedFeePreviews(
        sellPaymentState.copyWith(selectedUtxos: selectedUtxos),
      ),
    );
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

    final utxosResult = await _loadSellWalletUtxosUsecase.execute(
      walletId: wallet.id,
    );
    final live = _currentPaymentState ?? sellPaymentState;
    switch (utxosResult) {
      case Ok(:final value):
        emit(live.copyWith(utxos: value));
      case Err(:final failure):
        // Already logged at the boundary.
        emit(live.copyWith(error: failure));
    }
  }

  /// Rebuilds the payin estimate at the committed fee.
  ///
  /// Every emit past an await reads the live state and gives up when it is gone:
  /// this runs across `_getNetworkFeesUsecase` and a PSBT build, so a slow fetch
  /// routinely outlives the screen. Merging into a pre-await snapshot instead
  /// would republish the payment state over whatever replaced it — dropping the
  /// broadcast latch and re-arming Confirm on a payin already on the wire
  /// (#2522).
  Future<void> _recalculateFees(Emitter<SellState> emit) async {
    final sellPaymentState = _currentPaymentState;
    if (sellPaymentState == null) return;
    final wallet = sellPaymentState.selectedWallet;
    if (wallet == null) return;

    // The displayed fee belongs to the previous build until this one lands, so
    // drop it and let the row show its calculating state — pairing the old
    // amount with a just-changed fee tier reads as if nothing happened.
    // Restored on failure so the row can't be left calculating forever.
    final previousAbsoluteFees = sellPaymentState.absoluteFees;
    emit(sellPaymentState.copyWith(absoluteFees: null));

    // Every failure path below goes through here, so the row cannot be left in
    // its calculating state: the previous fee comes back and the user is told
    // why. Re-reads the live state because a confirmation may have started
    // while this recalculation was in flight.
    void restoreOnFailure(SellFailure failure) {
      final live = _currentPaymentState;
      if (live == null) return;
      emit(live.copyWith(absoluteFees: previousAbsoluteFees, error: failure));
    }

    try {
      final payinAmountSat = ConvertAmount.btcToSats(
        sellPaymentState.sellOrder.payinAmount,
      );

      if (wallet.isLiquid) {
        final addrResult = await _loadSellContextUsecase.addressAtIndex(
          walletId: wallet.id,
          index: 0,
        );
        final WalletAddress dummyAddressForFeeCalculation;
        switch (addrResult) {
          case Ok(:final value):
            dummyAddressForFeeCalculation = value;
          case Err(:final failure):
            restoreOnFailure(failure);
            return;
        }
        final psetResult = await _prepareSellLiquidPayinUsecase.execute(
          walletId: wallet.id,
          address: dummyAddressForFeeCalculation.address,
          amountSat: payinAmountSat,
          // 0.1 sat/vByte = 25 sat/kwu — Liquid's network minrelayfee default.
          feeRate: const RelativeFee(25),
        );
        final String pset;
        switch (psetResult) {
          case Ok(:final value):
            pset = value;
          case Err(:final failure):
            restoreOnFailure(failure);
            return;
        }
        final feesResult = await _calculateSellLiquidFeesUsecase.execute(
          pset: pset,
        );
        final int absoluteFees;
        switch (feesResult) {
          case Ok(:final value):
            absoluteFees = value;
          case Err(:final failure):
            restoreOnFailure(failure);
            return;
        }
        final liveAfterLiquidBuild = _currentPaymentState;
        if (liveAfterLiquidBuild == null) return;
        emit(liveAfterLiquidBuild.copyWith(absoluteFees: absoluteFees));
      } else {
        final feeOptionsResult = await _loadSellContextUsecase.networkFees(
          isLiquid: false,
        );
        final FeeOptions bitcoinFees;
        switch (feeOptionsResult) {
          case Ok(:final value):
            bitcoinFees = value;
          case Err(:final failure):
            restoreOnFailure(failure);
            return;
        }
        // Reprice the presets without touching the committed tier: a rate
        // refresh that silently reset the selection to Fastest would undo the
        // user's choice behind their back.
        final liveAfterFeeFetch = _currentPaymentState;
        if (liveAfterFeeFetch == null) return;
        final repriced = liveAfterFeeFetch.copyWith(bitcoinFees: bitcoinFees);
        final networkFee = repriced.selectedFee ?? bitcoinFees.fastest;
        final addressResult = await _payinBuildAddress(repriced, wallet);
        final String address;
        switch (addressResult) {
          case Ok(:final value):
            address = value;
          case Err(:final failure):
            restoreOnFailure(failure);
            return;
        }
        final preparedResult = await _prepareSellBitcoinPayinUsecase.execute(
          walletId: wallet.id,
          address: address,
          amountSat: payinAmountSat,
          networkFee: networkFee,
          selectedInputs: repriced.selectedUtxos.isNotEmpty
              ? repriced.selectedUtxos
              : null,
          replaceByFee: repriced.replaceByFee,
        );
        final PreparedSellBitcoinPayin preparedSend;
        switch (preparedResult) {
          case Ok(:final value):
            preparedSend = value;
          case Err(:final failure):
            restoreOnFailure(failure);
            return;
        }
        final absoluteFees = preparedSend.absoluteFees;
        final liveAfterBitcoinBuild = _currentPaymentState;
        if (liveAfterBitcoinBuild == null) return;
        emit(
          liveAfterBitcoinBuild.copyWith(
            bitcoinFees: bitcoinFees,
            absoluteFees: absoluteFees,
            bitcoinTxSize: preparedSend.txSize,
          ),
        );
      }
    } catch (e, st) {
      log.severe(
        message: 'Failed to recalculate the sell payin fees',
        error: e,
        trace: st,
      );
      final liveAfterFailure = _currentPaymentState;
      if (liveAfterFailure == null) return;
      emit(
        liveAfterFailure.copyWith(
          absoluteFees: previousAbsoluteFees,
          error: SellUnexpectedFailure('Failed to recalculate fees: $e'),
        ),
      );
    }
  }

  /// Address the payin is (or will be) built for. The order's own address keeps
  /// the estimate honest — a build against one of our own addresses can differ
  /// in vsize when the script types differ. Falls back to an own address only
  /// when the order has none yet.
  Future<Result<String, SellFailure>> _payinBuildAddress(
    SellPaymentState paymentState,
    Wallet wallet,
  ) async {
    final payinAddress = paymentState.sellOrder.bitcoinAddress;
    if (payinAddress != null && payinAddress.isNotEmpty) {
      return Ok(payinAddress);
    }
    final ownAddressResult = await _loadSellContextUsecase.addressAtIndex(
      walletId: wallet.id,
      index: 0,
    );
    return switch (ownAddressResult) {
      Ok(:final value) => Ok(value.address),
      Err(:final failure) => Err(failure),
    };
  }

  /// Drops every cached preview and invalidates in-flight builds. Call whenever
  /// the payin's shape changes: a slot still holding the old shape's fee would
  /// price the modal for a transaction we are no longer building.
  SellPaymentState _clearedFeePreviews(SellPaymentState paymentState) {
    _bitcoinPreviewEpoch++;
    return paymentState.copyWith(feePreviewCache: BitcoinFeePreviewCache.empty);
  }

  /// Payment state while fee selection is still allowed, or null when the
  /// event must be ignored — no payment in flight, a Liquid payin (no fee
  /// choice), or a confirmation already running (#2522).
  SellPaymentState? get _feeEditablePaymentState {
    final current = _currentPaymentState;
    if (current == null) return null;
    return current.canEditFees ? current : null;
  }

  Future<void> _onFeeOptionSelected(
    SellFeeOptionSelected event,
    Emitter<SellState> emit,
  ) async {
    final current = _feeEditablePaymentState;
    if (current == null) return;
    // Picking a preset is itself a commit, so any custom-fee arm is discarded
    // rather than rolled back.
    emit(
      current.copyWith(
        selectedFeeOption: event.feeSelection,
        armPriorSelection: null,
        armPriorCustomFee: null,
      ),
    );
    await _recalculateFees(emit);
  }

  Future<void> _onCustomFeeChanged(
    SellCustomFeeChanged event,
    Emitter<SellState> emit,
  ) async {
    final current = _feeEditablePaymentState;
    if (current == null) return;
    emit(
      current.copyWith(
        customFee: event.fee,
        selectedFeeOption: FeeSelection.custom,
        armPriorSelection: null,
        armPriorCustomFee: null,
      ),
    );
    await _recalculateFees(emit);
  }

  Future<void> _onCustomFeeArmed(
    SellCustomFeeArmed event,
    Emitter<SellState> emit,
  ) async {
    final current = _feeEditablePaymentState;
    if (current == null) return;
    // The typed rate just changed, so only the cached custom slot is wrong — it
    // prices the previous rate. The preset slots still describe the same payin
    // and must survive, or the first keystroke would blank their prices until
    // the modal is reopened. Bumping the epoch discards a custom preview still
    // in flight for the older rate, so it cannot land on top of the new one.
    _bitcoinPreviewEpoch++;
    final clearedCustomSlot = current.feePreviewCache.withSlot(
      FeeSelection.custom,
      const BitcoinFeePreviewSlot(),
    );
    if (current.armPriorSelection == null) {
      emit(
        current.copyWith(
          armPriorSelection: current.selectedFeeOption,
          armPriorCustomFee: current.customFee,
          selectedFeeOption: FeeSelection.custom,
          customFee: event.fee,
          feePreviewCache: clearedCustomSlot,
        ),
      );
    } else {
      emit(
        current.copyWith(
          customFee: event.fee,
          feePreviewCache: clearedCustomSlot,
        ),
      );
    }
  }

  Future<void> _onCustomFeeDisarmed(
    SellCustomFeeDisarmed event,
    Emitter<SellState> emit,
  ) async {
    final current = _feeEditablePaymentState;
    if (current == null) return;
    if (current.armPriorSelection == null) return;
    emit(
      current.copyWith(
        selectedFeeOption: current.armPriorSelection!,
        customFee: current.armPriorCustomFee,
        armPriorSelection: null,
        armPriorCustomFee: null,
      ),
    );
  }

  Future<void> _onCustomFeeFinalized(
    SellCustomFeeFinalized event,
    Emitter<SellState> emit,
  ) async {
    final current = _feeEditablePaymentState;
    if (current == null) return;
    if (current.armPriorSelection == null) return;
    final fee = current.customFee;
    final txSize = current.bitcoinTxSize ?? 140;
    if (fee != null &&
        fee.aboveMinRelay(
          txSize: txSize,
          floorSatPerKwu: current.bitcoinFees?.minRelay.satPerKwu,
        )) {
      await _onCustomFeeChanged(SellCustomFeeChanged(fee), emit);
    } else {
      await _onCustomFeeDisarmed(const SellCustomFeeDisarmed(), emit);
    }
  }

  Future<void> _onCustomFeePreviewRequested(
    SellCustomFeePreviewRequested event,
    Emitter<SellState> emit,
  ) async {
    final current = _feeEditablePaymentState;
    if (current == null) return;
    final wallet = current.selectedWallet!;
    emit(
      current.copyWith(
        feePreviewCache: current.feePreviewCache.copyWith(customLoading: true),
      ),
    );
    final epoch = _bitcoinPreviewEpoch;
    final addressResult = await _payinBuildAddress(current, wallet);
    final String address;
    switch (addressResult) {
      case Ok(:final value):
        address = value;
      case Err():
        return;
    }
    final slot = await _previewBitcoinFeeUsecase.execute(
      walletId: wallet.id,
      address: address,
      networkFee: event.fee,
      amountSat: ConvertAmount.btcToSats(current.sellOrder.payinAmount),
      replaceByFee: current.replaceByFee,
      selectedInputs: current.selectedUtxos,
      drain: false,
    );
    // The payin's shape changed while this build ran, so the slot describes a
    // transaction we are no longer offering.
    if (epoch != _bitcoinPreviewEpoch) return;
    final live = _currentPaymentState;
    if (live == null) return;
    emit(
      live.copyWith(
        feePreviewCache: live.feePreviewCache
            .withSlot(FeeSelection.custom, slot)
            .copyWith(customLoading: false),
      ),
    );
  }

  Future<void> _onPresetFeesPreviewRequested(
    SellPresetFeesPreviewRequested event,
    Emitter<SellState> emit,
  ) async {
    final current = _feeEditablePaymentState;
    if (current == null) return;
    final presets = current.bitcoinFees;
    if (presets == null) return;
    final wallet = current.selectedWallet!;
    emit(
      current.copyWith(
        feePreviewCache: current.feePreviewCache.copyWith(presetsLoading: true),
      ),
    );
    final epoch = _bitcoinPreviewEpoch;
    final addressResult = await _payinBuildAddress(current, wallet);
    final String address;
    switch (addressResult) {
      case Ok(:final value):
        address = value;
      case Err():
        return;
    }
    final slots = await _previewBitcoinFeePresetsUsecase.execute(
      presets: presets,
      walletId: wallet.id,
      address: address,
      amountSat: ConvertAmount.btcToSats(current.sellOrder.payinAmount),
      replaceByFee: current.replaceByFee,
      selectedInputs: current.selectedUtxos,
      drain: false,
    );
    if (epoch != _bitcoinPreviewEpoch) return;
    final live = _currentPaymentState;
    if (live == null) return;
    emit(
      live.copyWith(
        feePreviewCache: live.feePreviewCache.copyWith(
          fastest: slots[FeeSelection.fastest] ?? const BitcoinFeePreviewSlot(),
          economic:
              slots[FeeSelection.economic] ?? const BitcoinFeePreviewSlot(),
          slow: slots[FeeSelection.slow] ?? const BitcoinFeePreviewSlot(),
          presetsLoading: false,
        ),
      ),
    );
  }

  // ────── FeeModalViewState + FeeModalActions adoption ──────
  // The shared modal in lib/core/widgets/fees/ sees the same snapshot and
  // action surface it gets from SendCubit and TransferBloc; the sell flow's
  // own state shape and event dispatch collapse here. Fee state only exists
  // on SellPaymentState, so every other state maps to the neutral defaults
  // (the modal cannot be open from those screens anyway).

  static FeeModalSnapshot _modalSnapshotFromState(SellState s) {
    final payment = s is SellPaymentState ? s : null;
    return FeeModalSnapshot(
      feePresets: payment?.bitcoinFees,
      customFee: payment?.customFee,
      selectedFeeOption: payment?.selectedFeeOption ?? FeeSelection.fastest,
      feePreviewCache: payment?.feePreviewCache ?? BitcoinFeePreviewCache.empty,
      exchangeRate: payment?.exchangeRateEstimate ?? 0.0,
      fiatCurrencyCode: payment?.fiatCurrency.code ?? '',
      txSize: payment?.bitcoinTxSize ?? 140,
    );
  }

  @override
  FeeModalSnapshot get snapshot => _modalSnapshotFromState(state);

  @override
  Stream<FeeModalSnapshot> get snapshots => stream.map(_modalSnapshotFromState);

  @override
  void requestPresetPreviews() =>
      add(const SellEvent.presetFeesPreviewRequested());

  @override
  void requestCustomFeePreview(NetworkFee fee) =>
      add(SellEvent.customFeePreviewRequested(fee));

  @override
  void armCustomFee(NetworkFee fee) => add(SellEvent.customFeeArmed(fee));

  @override
  void disarmCustomFee() => add(const SellEvent.customFeeDisarmed());

  @override
  void finalizeArmedCustomFee() => add(const SellEvent.customFeeFinalized());

  @override
  void selectFeeOption(FeeSelection selection) =>
      add(SellEvent.feeOptionSelected(selection));

  @override
  Future<void> close() async {
    _stopPolling();
    await _payjoinSubscription?.cancel();
    return super.close();
  }
}
