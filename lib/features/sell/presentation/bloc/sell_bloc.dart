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
import 'package:bb_mobile/core/fees/domain/fee_preview_cache.dart';
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
import 'package:bb_mobile/features/sell/domain/label_completed_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/create_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/refresh_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/get_payjoin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/get_payjoin_trading_enabled_usecase.dart';
import 'package:bb_mobile/features/sell/domain/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/set_payjoin_trading_enabled_usecase.dart';
import 'package:bb_mobile/features/sell/domain/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/core/widgets/fees/fee_modal_controller.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_presets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bip21_uri/bip21_uri.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_payjoin/bull_payjoin.dart'
    show PayjoinSenderSession, PayjoinSession, PayjoinSessionWindow;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sell_bloc.freezed.dart';
part 'sell_event.dart';
part 'sell_state.dart';

class SellBloc extends Bloc<SellEvent, SellState>
    implements FeeModalActions, FeeModalViewState {
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
    required this._sendWithPayjoinUsecase,
    required this._watchPayjoinUsecase,
    required this._getPayjoinUsecase,
    required this._getPayjoinTradingEnabledUsecase,
    required this._setPayjoinTradingEnabledUsecase,
    required this._getNetworkFeesUsecase,
    required this._calculateLiquidAbsoluteFeesUsecase,
    required this._calculateBitcoinAbsoluteFeesUsecase,
    required this._convertSatsToCurrencyAmountUsecase,
    required this._getAddressAtIndexUsecase,
    required this._getWalletUtxosUsecase,
    required this._getOrderUsecase,
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
    on<SellPayjoinToggled>(_onPayjoinToggled, transformer: droppable());
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
  final SendWithPayjoinUsecase _sendWithPayjoinUsecase;
  final WatchPayjoinUsecase _watchPayjoinUsecase;
  final GetPayjoinUsecase _getPayjoinUsecase;
  final GetPayjoinTradingEnabledUsecase _getPayjoinTradingEnabledUsecase;
  final SetPayjoinTradingEnabledUsecase _setPayjoinTradingEnabledUsecase;
  final GetNetworkFeesUsecase _getNetworkFeesUsecase;
  final CalculateLiquidAbsoluteFeesUsecase _calculateLiquidAbsoluteFeesUsecase;
  final CalculateBitcoinAbsoluteFeesUsecase
  _calculateBitcoinAbsoluteFeesUsecase;
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrencyAmountUsecase;
  final GetAddressAtIndexUsecase _getAddressAtIndexUsecase;
  final GetWalletUtxosUsecase _getWalletUtxosUsecase;
  final GetOrderUsecase _getOrderUsecase;
  final LabelsFacade _labelsFacade;
  final LabelCompletedSellOrderUsecase _labelCompletedSellOrderUsecase;
  final PreviewBitcoinFeeUsecase _previewBitcoinFeeUsecase;
  final PreviewBitcoinFeePresetsUsecase _previewBitcoinFeePresetsUsecase;
  Timer? _pollingTimer;
  StreamSubscription<PayjoinSession>? _payjoinSubscription;
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
        bitcoinFees = await _getNetworkFeesUsecase.execute(isLiquid: false);
        // Fastest is the default selection, so the estimate shown on arrival
        // is the estimate for the tier the payin would be built at.
        final preparedSend = await _prepareBitcoinSendUsecase.execute(
          walletId: event.wallet.id,
          address: dummyAddressForFeeCalculation.address,
          amountSat: requiredAmountSat,
          networkFee: bitcoinFees.fastest,
        );
        bitcoinTxSize = preparedSend.txSize;
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
        // Asking for payjoin only makes the exchange publish a bip21URI on the
        // order; whether the payin actually uses it is decided at confirmation
        // time. So requesting it here costs nothing when the payment ends up
        // being an ordinary one — the exchange credits a plain transaction to
        // the same address either way.
        usePayjoin:
            !event.wallet.isLiquid &&
            walletSelectionState.userSummary.payjoinReceiveEnabled,
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
        expectedDepositAddress: paymentState.sellOrder.toAddress,
      );

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
    if (sellPaymentState.isUpdatingPayjoin) return;

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
        // The rate the user committed in the fee modal, which defaults to
        // Fastest. The absolute fee from the last estimate is the fallback for
        // the case where the presets went missing — being unable to pick a fee
        // must not block paying the order.
        final absoluteFees = sellPaymentState.absoluteFees;
        final networkFee =
            sellPaymentState.selectedFee ??
            (absoluteFees != null ? NetworkFee.absolute(absoluteFees) : null);
        if (networkFee == null) {
          throw const SellError.unexpected(
            message: 'Transaction fees not calculated. Please try again.',
          );
        }

        final preparedSend = await _prepareBitcoinSendUsecase.execute(
          walletId: wallet.id,
          address: sellPaymentState.sellOrder.bitcoinAddress!,
          amountSat: payinAmountSat,
          networkFee: networkFee,
          selectedInputs: sellPaymentState.selectedUtxos.isNotEmpty
              ? sellPaymentState.selectedUtxos
              : null,
          replaceByFee: sellPaymentState.replaceByFee,
        );
        final absoluteFeesUpdated = await _calculateBitcoinAbsoluteFeesUsecase
            .execute(psbt: preparedSend.unsignedPsbt);
        // An absolute custom fee was checked against the *previous* vsize; if
        // this build came out larger it can sit below the relay floor, which
        // strands the payin unbroadcastable. Re-check the built fee against the
        // built vsize before signing rather than trusting BDK to refuse.
        if (!NetworkFee.absolute(absoluteFeesUpdated).aboveMinRelay(
          txSize: preparedSend.txSize,
          floorSatPerKwu: sellPaymentState.bitcoinFees?.minRelay.satPerKwu,
        )) {
          throw const SellError.unexpected(
            message:
                'The selected fee is below the network minimum. '
                'Choose a higher fee priority and try again.',
          );
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

        final tradingEnabled = await _getPayjoinTradingEnabledUsecase.execute();
        if (!tradingEnabled && sellPaymentState.isPayjoinEnabled) {
          final current = _currentPaymentState;
          if (current != null) {
            emit(current.copyWith(isPayjoinEnabled: false));
          }
        }
        if (sellPaymentState.isPayjoinEnabled &&
            tradingEnabled &&
            payjoinBip21 != null &&
            payjoinWindow != null) {
          log.info('Sell Payjoin sender creation started');
          PayjoinSenderSession payjoinSender;
          try {
            payjoinSender = await _sendWithPayjoinUsecase.execute(
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
          } on SendPayjoinException {
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
            final persisted = await _getPayjoinUsecase.execute(payjoinBip21);
            if (persisted is! PayjoinSenderSession) rethrow;
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
      }
      if (!waitingForPayjoin) await _completeAfterBroadcast(emit);
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
    _payjoinSubscription = _watchPayjoinUsecase
        .execute(sessionId)
        .listen(
          (session) => add(SellEvent.payjoinSessionUpdated(session)),
          onError: (Object error, StackTrace stackTrace) {
            log.warning('Payjoin session watch failed');
            Future<void>.delayed(const Duration(seconds: 5), () {
              if (!isClosed && _activePayjoinSessionId == sessionId) {
                _watchPayjoin(sessionId, orderId: orderId);
              }
            });
          },
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

    final latestOrder = await _getOrderUsecase.execute(
      orderId: paymentState.sellOrder.orderId,
    );

    if (latestOrder is! SellOrder) {
      throw const SellError.unexpected(
        message: 'Expected SellOrder but received a different order type',
      );
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
    final confirmationDeadline = current.sellOrder.confirmationDeadline;
    if (confirmationDeadline != null &&
        !confirmationDeadline.isAfter(DateTime.now())) {
      add(const SellEvent.orderRefreshTimePassed());
    }
  }

  Future<void> _onPayjoinToggled(
    SellPayjoinToggled event,
    Emitter<SellState> emit,
  ) async {
    final paymentState = _currentPaymentState;
    if (paymentState == null || paymentState.selectedWallet?.isLiquid == true) {
      return;
    }
    if (paymentState.isConfirmingPayment ||
        paymentState.isPayinBroadcast ||
        paymentState.isUpdatingPayjoin) {
      return;
    }
    final previous = paymentState.isPayjoinEnabled;
    emit(paymentState.copyWith(isUpdatingPayjoin: true, error: null));
    final failure = await _setPayjoinTradingEnabledUsecase.execute(
      event.enabled,
    );
    final current = _currentPaymentState;
    if (current == null) return;
    if (failure == null) {
      emit(
        current.copyWith(
          isPayjoinEnabled: event.enabled,
          isUpdatingPayjoin: false,
        ),
      );
    } else {
      emit(
        current.copyWith(
          isPayjoinEnabled: previous,
          isUpdatingPayjoin: false,
          error: failure,
        ),
      );
    }
  }

  Future<void> _onPollOrderStatus(
    SellPollOrderStatus event,
    Emitter<SellState> emit,
  ) async {
    if (state is SellSuccessState) {
      final sellSuccessState = state as SellSuccessState;
      try {
        final latestOrder = await _getOrderUsecase.execute(
          orderId: sellSuccessState.sellOrder.orderId,
        );
        if (latestOrder is! SellOrder) {
          log.severe(
            error: 'Expected SellOrder but received a different order type',
            trace: StackTrace.current,
          );
          return;
        }
        await _labelPayjoinSellTransaction(latestOrder, null);
        // The explicit order-completion event is the only legitimate writer
        // of privileged exchange labels (issue #2624).
        await _labelCompletedSellOrderUsecase.execute(order: latestOrder);
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

      final current = _currentPaymentState;
      if (current == null) return;
      if (!current.isPayinBroadcast) {
        try {
          validateSellOrderDepositAddress(
            order: latestOrder,
            expectedDepositAddress: current.sellOrder.toAddress,
          );
        } on DepositAddressChangedSellError catch (error, stackTrace) {
          log.severe(error: error, trace: stackTrace);
          _stopPolling();
          emit(current.copyWith(error: error, isPolling: false));
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
        final liveAfterLiquidBuild = _currentPaymentState;
        if (liveAfterLiquidBuild == null) return;
        emit(liveAfterLiquidBuild.copyWith(absoluteFees: absoluteFees));
      } else {
        final bitcoinFees = await _getNetworkFeesUsecase.execute(
          isLiquid: false,
        );
        // Reprice the presets without touching the committed tier: a rate
        // refresh that silently reset the selection to Fastest would undo the
        // user's choice behind their back.
        final liveAfterFeeFetch = _currentPaymentState;
        if (liveAfterFeeFetch == null) return;
        final repriced = liveAfterFeeFetch.copyWith(bitcoinFees: bitcoinFees);
        final networkFee = repriced.selectedFee ?? bitcoinFees.fastest;
        final address = await _payinBuildAddress(repriced, wallet);
        final preparedSend = await _prepareBitcoinSendUsecase.execute(
          walletId: wallet.id,
          address: address,
          amountSat: payinAmountSat,
          networkFee: networkFee,
          selectedInputs: repriced.selectedUtxos.isNotEmpty
              ? repriced.selectedUtxos
              : null,
          replaceByFee: repriced.replaceByFee,
        );
        final absoluteFees = await _calculateBitcoinAbsoluteFeesUsecase.execute(
          psbt: preparedSend.unsignedPsbt,
        );
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
    } catch (e) {
      final liveAfterFailure = _currentPaymentState;
      if (liveAfterFailure == null) return;
      emit(
        liveAfterFailure.copyWith(
          absoluteFees: previousAbsoluteFees,
          error: SellError.unexpected(
            message: 'Failed to recalculate fees: $e',
          ),
        ),
      );
    }
  }

  /// Address the payin is (or will be) built for. The order's own address keeps
  /// the estimate honest — a build against one of our own addresses can differ
  /// in vsize when the script types differ. Falls back to an own address only
  /// when the order has none yet.
  Future<String> _payinBuildAddress(
    SellPaymentState paymentState,
    Wallet wallet,
  ) async {
    final payinAddress = paymentState.sellOrder.bitcoinAddress;
    if (payinAddress != null && payinAddress.isNotEmpty) return payinAddress;
    final ownAddress = await _getAddressAtIndexUsecase.execute(
      walletId: wallet.id,
      index: 0,
    );
    return ownAddress.address;
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
    final address = await _payinBuildAddress(current, wallet);
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
    final address = await _payinBuildAddress(current, wallet);
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
