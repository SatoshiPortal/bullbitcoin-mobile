import 'dart:async';

import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/errors/pay_error.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/fees/domain/fee_preview_cache.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart' hide Network;
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/pay/domain/create_pay_order_usecase.dart';
import 'package:bb_mobile/features/pay/domain/get_payjoin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/refresh_pay_order_usecase.dart';
import 'package:bb_mobile/features/pay/domain/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/watch_payjoin_usecase.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
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

part 'pay_bloc.freezed.dart';
part 'pay_event.dart';
part 'pay_state.dart';

class PayBloc extends Bloc<PayEvent, PayState>
    implements FeeModalActions, FeeModalViewState {
  PayBloc({
    required this._getExchangeUserSummaryUsecase,
    required this._placePayOrderUsecase,
    required this._refreshPayOrderUsecase,
    required this._prepareBitcoinSendUsecase,
    required this._prepareLiquidSendUsecase,
    required this._signBitcoinTxUsecase,
    required this._signLiquidTxUsecase,
    required this._broadcastBitcoinTransactionUsecase,
    required this._broadcastLiquidTransactionUsecase,
    required this._sendWithPayjoinUsecase,
    required this._watchPayjoinUsecase,
    required this._getPayjoinUsecase,
    required this._getNetworkFeesUsecase,
    required this._calculateLiquidAbsoluteFeesUsecase,
    required this._calculateBitcoinAbsoluteFeesUsecase,
    required this._convertSatsToCurrencyAmountUsecase,
    required this._getAddressAtIndexUsecase,
    required this._getWalletUtxosUsecase,
    required this._getOrderUsecase,
    required this._previewBitcoinFeeUsecase,
    required this._previewBitcoinFeePresetsUsecase,
  }) : super(PayRecipientSelectionState()) {
    on<PayStarted>(_onStarted);
    on<PayRecipientSelected>(_onRecipientSelected);
    on<PayAmountInputContinuePressed>(_onAmountInputContinuePressed);
    on<PayWalletSelected>(_onWalletSelected);
    on<PayExternalWalletNetworkSelected>(_onExternalWalletNetworkSelected);
    on<PayOrderRefreshTimePassed>(_onOrderRefreshTimePassed);
    on<PaySendPaymentConfirmed>(
      _onSendPaymentConfirmed,
      transformer: droppable(),
    );
    on<PayPollOrderStatus>(_onPollOrderStatus);
    on<PayPayjoinToggled>(_onPayjoinToggled);
    on<PayPayjoinSessionUpdated>(_onPayjoinSessionUpdated);
    on<PayReplaceByFeeChanged>(_onReplaceByFeeChanged);
    on<PayUtxosSelected>(_onUtxosSelected);
    on<PayLoadUtxos>(_onLoadUtxos);
    on<PayUpdateOrderStatus>(_onUpdateOrderStatus);
    on<PayFeeOptionSelected>(_onFeeOptionSelected);
    on<PayCustomFeeChanged>(_onCustomFeeChanged);
    on<PayCustomFeeArmed>(_onCustomFeeArmed);
    on<PayCustomFeeDisarmed>(_onCustomFeeDisarmed);
    on<PayCustomFeeFinalized>(_onCustomFeeFinalized);
    on<PayCustomFeePreviewRequested>(_onCustomFeePreviewRequested);
    on<PayPresetFeesPreviewRequested>(_onPresetFeesPreviewRequested);
  }

  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final PlacePayOrderUsecase _placePayOrderUsecase;
  final RefreshPayOrderUsecase _refreshPayOrderUsecase;

  final PrepareBitcoinSendUsecase _prepareBitcoinSendUsecase;
  final PrepareLiquidSendUsecase _prepareLiquidSendUsecase;
  final SignBitcoinTxUsecase _signBitcoinTxUsecase;
  final SignLiquidTxUsecase _signLiquidTxUsecase;
  final BroadcastBitcoinTransactionUsecase _broadcastBitcoinTransactionUsecase;
  final BroadcastLiquidTransactionUsecase _broadcastLiquidTransactionUsecase;
  final SendWithPayjoinUsecase _sendWithPayjoinUsecase;
  final WatchPayjoinUsecase _watchPayjoinUsecase;
  final GetPayjoinUsecase _getPayjoinUsecase;
  final GetNetworkFeesUsecase _getNetworkFeesUsecase;
  final CalculateLiquidAbsoluteFeesUsecase _calculateLiquidAbsoluteFeesUsecase;
  final CalculateBitcoinAbsoluteFeesUsecase
  _calculateBitcoinAbsoluteFeesUsecase;
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrencyAmountUsecase;
  final GetAddressAtIndexUsecase _getAddressAtIndexUsecase;
  final GetWalletUtxosUsecase _getWalletUtxosUsecase;
  final GetOrderUsecase _getOrderUsecase;
  final PreviewBitcoinFeeUsecase _previewBitcoinFeeUsecase;
  final PreviewBitcoinFeePresetsUsecase _previewBitcoinFeePresetsUsecase;
  Timer? _pollingTimer;
  bool _isOrderRequestInFlight = false;
  String? _pendingOrderStatusUpdateId;
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

  /// Bumped whenever the cached previews stop describing the payin being built
  /// (typed rate, coin selection, RBF, a refreshed payin amount). A preview
  /// build that started under an older epoch is discarded on return instead of
  /// writing a slot for a tx shape that no longer exists.
  int _bitcoinPreviewEpoch = 0;

  Future<void> _onStarted(PayStarted event, Emitter<PayState> emit) async {
    final recipientSelectionState = state.cleanRecipientSelectionState;
    emit(recipientSelectionState!.copyWith(isLoadingUserSummary: true));
    try {
      final userSummary = await _getExchangeUserSummaryUsecase.execute();

      emit(recipientSelectionState.copyWith(userSummary: userSummary));
    } on GetExchangeUserSummaryException catch (e) {
      emit(
        recipientSelectionState.copyWith(
          error: PayError.unexpected(message: e.message),
        ),
      );
    } finally {
      if (state is PayRecipientSelectionState) {
        emit(
          (state as PayRecipientSelectionState).copyWith(
            isLoadingUserSummary: false,
          ),
        );
      }
    }
  }

  Future<void> _onRecipientSelected(
    PayRecipientSelected event,
    Emitter<PayState> emit,
  ) async {
    final recipientSelectionState = state.cleanRecipientSelectionState;
    if (recipientSelectionState == null) {
      log.severe(
        error: 'Expected to be on PayRecipientSelectionState',
        trace: StackTrace.current,
      );
      return;
    }

    // First emit the recipient selection state again since we went back to it,
    // So that the change to amount input state can be listened to properly.
    emit(recipientSelectionState);

    final amountInputState = recipientSelectionState.toAmountInputState(
      selectedRecipient: event.recipient,
    );
    emit(amountInputState);
  }

  Future<void> _onAmountInputContinuePressed(
    PayAmountInputContinuePressed event,
    Emitter<PayState> emit,
  ) async {
    // Never tear down a payment in flight: going back to the amount input
    // drops the payment state, and the payjoin session of the current order
    // would keep negotiating orphaned — its resolution could then latch onto
    // a later order's payment state.
    if (_hasPaymentInFlight) return;

    // We should be on a PayAmountInputState here
    final amountInputState = state.cleanAmountInputState;
    if (amountInputState == null) {
      // Unexpected state, do nothing
      log.severe(
        error: 'Expected to be on PayAmountInputState',
        trace: StackTrace.current,
      );
      return;
    }
    emit(amountInputState);

    final amount = double.tryParse(event.amountInput);
    if (amount == null || amount <= 0) {
      log.severe(error: 'Invalid amount input', trace: StackTrace.current);
      return;
    }

    final fiatAmount = FiatAmount(amount);

    final walletSelectionState = amountInputState.toWalletSelectionState(
      amount: fiatAmount,
      paymentDescription: event.paymentDescription,
    );
    emit(walletSelectionState);
  }

  // From Sell: Select internal wallet, calculate fees, create pay order
  Future<void> _onWalletSelected(
    PayWalletSelected event,
    Emitter<PayState> emit,
  ) async {
    // Never tear down a payment in flight to start a new order: the pending
    // transaction pays the CURRENT order, and a new order built on top of an
    // active payjoin session inherits its resolution (cross-order latch —
    // the new order would show a success screen without ever being paid).
    if (_hasPaymentInFlight) return;

    final walletSelectionState = state.cleanWalletSelectionState;
    if (walletSelectionState == null) {
      log.severe(
        error: 'Expected to be on PayWalletSelectionState',
        trace: StackTrace.current,
      );
      return;
    }

    emit(walletSelectionState.copyWith(isCreatingPayOrder: true));

    int absoluteFees = 0;
    // Carried into the payment state so the confirmation screen can offer the
    // fee modal (#2521): it needs the presets to price the tiles and a vsize to
    // check an absolute custom fee against the relay floor.
    FeeOptions? bitcoinFees;
    int? bitcoinTxSize;
    // Assigned inside the try: the rate fetch can fail, and that failure must
    // surface through the catch below. Awaited outside any try (as this used
    // to be), a price-API failure escaped the handler entirely — no error
    // state, and the order-creation spinner stayed latched with no retry path.
    double exchangeRateEstimate = 0.0;
    // This builds a brand-new payment state, with its own order, wallet and
    // empty preview cache. A preview still in flight for the previous one would
    // otherwise land in that cache and price this payin with the last order's
    // fees.
    _bitcoinPreviewEpoch++;
    try {
      exchangeRateEstimate = await _convertSatsToCurrencyAmountUsecase.execute(
        currencyCode: walletSelectionState.currency.code,
      );

      final requiredAmountSat = ConvertAmount.fiatToSats(
        walletSelectionState.amount.amount,
        exchangeRateEstimate,
      );

      if (event.wallet.balanceSat.toInt() < requiredAmountSat) {
        emit(
          walletSelectionState.copyWith(
            error: PayError.unexpected(
              message:
                  'Insufficient balance. Required: $requiredAmountSat sats',
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
        // Fastest is the default selection, so the estimate shown on arrival is
        // the estimate for the tier the payin would be built at.
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
          error: PayError.unexpected(
            message: 'Failed to prepare transaction: $e',
          ),
        ),
      );
      return;
    }
    emit(walletSelectionState.copyWith(isCreatingPayOrder: true));
    try {
      final createdPayOrder = await _placePayOrderUsecase.execute(
        orderAmount: walletSelectionState.amount,
        recipientId: walletSelectionState.selectedRecipient.id,
        network: event.wallet.isLiquid
            ? OrderBitcoinNetwork.liquid
            : OrderBitcoinNetwork.bitcoin,
        paymentDescription: walletSelectionState.paymentDescription,
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
            payOrder: createdPayOrder,
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
            payOrder: createdPayOrder,
            absoluteFees: absoluteFees,
            exchangeRateEstimate: exchangeRateEstimate,
          ),
        );
      }
      _startPolling();
    } on PrepareLiquidSendException catch (e) {
      emit(
        walletSelectionState.copyWith(
          error: PayError.unexpected(message: e.message),
        ),
      );
    } on PrepareBitcoinSendException catch (e) {
      emit(
        walletSelectionState.copyWith(
          error: PayError.unexpected(message: e.message),
        ),
      );
    } on PayError catch (e) {
      emit(walletSelectionState.copyWith(error: e));
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
    } finally {
      if (state is PayWalletSelectionState) {
        emit(
          (state as PayWalletSelectionState).copyWith(
            isCreatingPayOrder: false,
          ),
        );
      }
    }
  }

  // From Sell: Select external wallet network, create pay order
  Future<void> _onExternalWalletNetworkSelected(
    PayExternalWalletNetworkSelected event,
    Emitter<PayState> emit,
  ) async {
    // Same guard as _onWalletSelected: switching the network rebuilds the
    // order, which must never happen while a payment is in flight.
    if (_hasPaymentInFlight) return;

    // We should be on a PayWalletSelection state here
    final walletSelectionState = state.cleanWalletSelectionState;
    if (walletSelectionState == null) {
      log.severe(
        error: 'Expected to be on PayWalletSelectionState',
        trace: StackTrace.current,
      );
      return;
    }

    emit(walletSelectionState.copyWith(isCreatingPayOrder: true));

    try {
      final createdPayOrder = await _placePayOrderUsecase.execute(
        orderAmount: walletSelectionState.amount,
        recipientId: walletSelectionState.selectedRecipient.id,
        network: event.network,
        paymentDescription: walletSelectionState.paymentDescription,
      );

      // Proceed to payment state
      emit(
        walletSelectionState.toReceivePaymentState(payOrder: createdPayOrder),
      );
      _startPolling();
    } on PayError catch (e) {
      emit(walletSelectionState.copyWith(error: e));
    } catch (e) {
      // Log unexpected errors
      log.severe(error: e, trace: StackTrace.current);
    } finally {
      if (state is PayWalletSelectionState) {
        emit(
          (state as PayWalletSelectionState).copyWith(
            isCreatingPayOrder: false,
          ),
        );
      }
    }
  }

  Future<void> _onOrderRefreshTimePassed(
    PayOrderRefreshTimePassed event,
    Emitter<PayState> emit,
  ) async {
    // We should be on a PayPaymentState
    final paymentState = _currentPaymentState;
    if (paymentState == null) {
      log.severe(
        error: 'Expected to be on PayPaymentState',
        trace: StackTrace.current,
      );
      return;
    }

    if (paymentState.isConfirmingPayment || paymentState.isPayinBroadcast) {
      return;
    }

    try {
      final refreshedOrder = await _refreshPayOrderUsecase.execute(
        orderId: paymentState.payOrder.orderId,
        expectedDepositAddress: paymentState.payOrder.toAddress,
      );

      final current = _currentPaymentState;
      if (current == null) return;
      if (current.isConfirmingPayment || current.isPayinBroadcast) return;

      final refreshed = current.copyWith(payOrder: refreshedOrder);
      // A new price lock moves the payin amount, which invalidates every
      // preview built for the old one.
      emit(
        refreshedOrder.payinAmount == current.payOrder.payinAmount
            ? refreshed
            : _clearedFeePreviews(refreshed),
      );
    } on PayError catch (e) {
      final current = _currentPaymentState;
      if (current == null) return;
      if (current.isConfirmingPayment || current.isPayinBroadcast) return;
      emit(current.copyWith(error: e));
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
    }
  }

  // From Sell: Send payment for internal wallets
  Future<void> _onSendPaymentConfirmed(
    PaySendPaymentConfirmed event,
    Emitter<PayState> emit,
  ) async {
    // We should be on a PayPaymentState
    final payPaymentState = state.cleanPaymentState;
    if (payPaymentState == null) {
      log.severe(
        error: 'Expected to be on PayPaymentState',
        trace: StackTrace.current,
      );
      return;
    }

    if (payPaymentState.isPayinBroadcast) {
      emit(payPaymentState.copyWith(isConfirmingPayment: true));
      try {
        await _completeAfterBroadcast(emit);
      } catch (e) {
        log.severe(error: e, trace: StackTrace.current);
      }
      return;
    }

    // Second half of the #2522 latch, for the payjoin path: the txid only
    // lands once the session resolves, so until then the *session* is what
    // says this order's payin is already committed. Its original transaction
    // is in the receiver's hands and can be broadcast at any moment, so
    // building a second one here would pay the order twice.
    if (_activePayjoinSessionId != null) {
      emit(payPaymentState.copyWith(isConfirmingPayment: true));
      return;
    }

    emit(payPaymentState.copyWith(isConfirmingPayment: true));
    var waitingForPayjoin = false;
    try {
      final wallet = payPaymentState.selectedWallet;
      if (wallet == null) {
        throw const PayError.unexpected(
          message: 'No wallet selected to send payment',
        );
      }
      final isLiquid = wallet.isLiquid;
      final payinAmountSat = ConvertAmount.btcToSats(
        payPaymentState.payOrder.payinAmount,
      );
      if (isLiquid) {
        final pset = await _prepareLiquidSendUsecase.execute(
          walletId: wallet.id,
          address: payPaymentState.payOrder.liquidAddress!,
          amountSat: payinAmountSat,
          // 0.1 sat/vByte = 25 sat/kwu — Liquid's network minrelayfee default.
          feeRate: const RelativeFee(25),
        );
        final signedPset = await _signLiquidTxUsecase.execute(
          pset: pset,
          walletId: wallet.id,
        );
        final txid = await _broadcastLiquidTransactionUsecase.execute(
          signedPset,
        );
        _latchBroadcast(emit, txid);
      } else {
        // The rate the user committed in the fee modal, which defaults to
        // Fastest. The absolute fee from the last estimate is the fallback for
        // the case where the presets went missing — being unable to pick a fee
        // must not block paying the order.
        final absoluteFees = payPaymentState.absoluteFees;
        final networkFee =
            payPaymentState.selectedFee ??
            (absoluteFees != null ? NetworkFee.absolute(absoluteFees) : null);
        if (networkFee == null) {
          throw const PayError.unexpected(
            message: 'Transaction fees not calculated. Please try again.',
          );
        }

        final preparedSend = await _prepareBitcoinSendUsecase.execute(
          walletId: wallet.id,
          address: payPaymentState.payOrder.bitcoinAddress!,
          amountSat: payinAmountSat,
          networkFee: networkFee,
          selectedInputs: payPaymentState.selectedUtxos.isNotEmpty
              ? payPaymentState.selectedUtxos
              : null,
          replaceByFee: payPaymentState.replaceByFee,
        );
        final absoluteFeesUpdated = await _calculateBitcoinAbsoluteFeesUsecase
            .execute(psbt: preparedSend.unsignedPsbt);
        // An absolute custom fee was checked against the *previous* vsize; if
        // this build came out larger it can sit below the relay floor, which
        // strands the payin unbroadcastable. Re-check the built fee against the
        // built vsize before signing rather than trusting BDK to refuse.
        if (!NetworkFee.absolute(absoluteFeesUpdated).aboveMinRelay(
          txSize: preparedSend.txSize,
          floorSatPerKwu: payPaymentState.bitcoinFees?.minRelay.satPerKwu,
        )) {
          throw const PayError.unexpected(
            message:
                'The selected fee is below the network minimum. '
                'Choose a higher fee priority and try again.',
          );
        }
        emit(
          (_currentPaymentState ?? payPaymentState).copyWith(
            absoluteFees: absoluteFeesUpdated,
            bitcoinTxSize: preparedSend.txSize,
          ),
        );
        final confirmationDeadline =
            payPaymentState.payOrder.confirmationDeadline;
        final payjoinWindow =
            payPaymentState.payOrder.bip21URI == null ||
                confirmationDeadline == null
            ? null
            : PayjoinSessionWindow.forOrderDeadline(confirmationDeadline);
        if (payPaymentState.isPayjoinEnabled && payjoinWindow != null) {
          final payjoinBip21 = payPaymentState.payOrder.bip21URI!;
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
              'Pay Payjoin start failed but session ${persisted.logRef} is '
              'persisted (status=${persisted.status.name}); adopting it '
              'instead of re-arming Confirm',
            );
            payjoinSender = persisted;
          }
          _watchPayjoin(
            payjoinSender.id,
            orderId: payPaymentState.payOrder.orderId,
          );
          waitingForPayjoin = true;
        } else {
          final signedTx = await _signBitcoinTxUsecase.execute(
            psbt: preparedSend.unsignedPsbt,
            walletId: wallet.id,
          );
          final txid = await _broadcastBitcoinTransactionUsecase.execute(
            signedTx.signedPsbt,
            isPsbt: true,
          );
          _latchBroadcast(emit, txid);
        }
      }
      if (!waitingForPayjoin) await _completeAfterBroadcast(emit);
    } on PrepareLiquidSendException catch (e) {
      _emitSendPaymentError(emit, PayError.unexpected(message: e.message));
    } on PrepareBitcoinSendException catch (e) {
      _emitSendPaymentError(emit, PayError.unexpected(message: e.toString()));
    } on SignLiquidTxException catch (e) {
      _emitSendPaymentError(emit, PayError.unexpected(message: e.toString()));
    } on SignBitcoinTxException catch (e) {
      _emitSendPaymentError(emit, PayError.unexpected(message: e.toString()));
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      _emitSendPaymentError(emit, PayError.unexpected(message: e.toString()));
    } finally {
      final current = _currentPaymentState;
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
          (session) => add(PayEvent.payjoinSessionUpdated(session)),
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
    PayPayjoinSessionUpdated event,
    Emitter<PayState> emit,
  ) async {
    final session = event.session;
    if (session.id != _activePayjoinSessionId || session.isOngoing) return;

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
    if (current.payOrder.orderId != sessionOrderId) {
      log.severe(
        error:
            'Resolved Payjoin session belongs to a different order; ignoring',
        trace: StackTrace.current,
      );
      return;
    }

    if (session.isExpired) {
      emit(current.copyWith(isConfirmingPayment: false, error: null));
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

  void _onPayjoinToggled(PayPayjoinToggled event, Emitter<PayState> emit) {
    final paymentState = _currentPaymentState;
    if (paymentState == null || paymentState.selectedWallet?.isLiquid == true) {
      return;
    }
    if (paymentState.isConfirmingPayment || paymentState.isPayinBroadcast) {
      return;
    }
    emit(paymentState.copyWith(isPayjoinEnabled: event.enabled));
  }

  // From Sell: Poll for order status
  Future<void> _onPollOrderStatus(
    PayPollOrderStatus event,
    Emitter<PayState> emit,
  ) async {
    if (_isOrderRequestInFlight) return;
    _isOrderRequestInFlight = true;

    try {
      final payPaymentState = _currentPaymentState;
      if (payPaymentState == null) return;
      final requestedOrderId = payPaymentState.payOrder.orderId;

      final latestOrder = await _getOrderUsecase.execute(
        orderId: requestedOrderId,
      );

      if (latestOrder is! FiatPaymentOrder) {
        log.severe(
          error:
              'Expected FiatPaymentOrder but received a different order type',
          trace: StackTrace.current,
        );
        return;
      }

      final current = _currentPaymentState;
      if (current == null) return;
      if (!current.isPayinBroadcast) {
        try {
          validatePayOrderDepositAddress(
            order: latestOrder,
            expectedDepositAddress: current.payOrder.toAddress,
          );
        } on DepositAddressChangedPayError catch (error, stackTrace) {
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
        emit(
          current
              .copyWith(payOrder: latestOrder, isPolling: false)
              .toSuccessState(payOrder: latestOrder),
        );
      } else {
        emit(current.copyWith(payOrder: latestOrder, isPolling: true));
      }
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
    } finally {
      _isOrderRequestInFlight = false;
      final pendingOrderId = _pendingOrderStatusUpdateId;
      _pendingOrderStatusUpdateId = null;
      if (pendingOrderId != null && !emit.isDone) {
        await _refreshOrderStatusForSuccess(pendingOrderId, emit);
      }
    }
  }

  // From Sell: Toggle RBF and recalculate fees
  Future<void> _onReplaceByFeeChanged(
    PayReplaceByFeeChanged event,
    Emitter<PayState> emit,
  ) async {
    final payPaymentState = _feeEditablePaymentState;
    if (payPaymentState == null) return;
    // RBF changes the sequence numbers, so every cached preview PSBT is for a
    // different transaction now.
    emit(
      _clearedFeePreviews(
        payPaymentState.copyWith(replaceByFee: event.replaceByFee),
      ),
    );
    await _recalculateFees(emit);
  }

  // From Sell: Select/deselect UTXOs
  Future<void> _onUtxosSelected(
    PayUtxosSelected event,
    Emitter<PayState> emit,
  ) async {
    final payPaymentState = _feeEditablePaymentState;
    if (payPaymentState == null) return;
    final selectedUtxos = event.utxos;

    // Coin selection changed — the previews were priced on the old input set.
    emit(
      _clearedFeePreviews(
        payPaymentState.copyWith(selectedUtxos: selectedUtxos),
      ),
    );
    await _recalculateFees(emit);
  }

  // From Sell: Load wallet UTXOs
  Future<void> _onLoadUtxos(PayLoadUtxos event, Emitter<PayState> emit) async {
    if (state is! PayPaymentState) return;

    final payPaymentState = state as PayPaymentState;
    final wallet = payPaymentState.selectedWallet;
    if (wallet == null) return;

    try {
      final utxos = await _getWalletUtxosUsecase.execute(walletId: wallet.id);
      final current = _currentPaymentState;
      if (current == null) return;
      emit(current.copyWith(utxos: utxos));
    } catch (e) {
      final current = _currentPaymentState;
      if (current == null) return;
      emit(
        current.copyWith(
          error: PayError.unexpected(message: 'Failed to load UTXOs: $e'),
        ),
      );
    }
  }

  // Update order status for SINPE móvil success screen
  Future<void> _onUpdateOrderStatus(
    PayUpdateOrderStatus event,
    Emitter<PayState> emit,
  ) async {
    if (_isOrderRequestInFlight) {
      _pendingOrderStatusUpdateId = event.orderId;
      return;
    }

    await _refreshOrderStatusForSuccess(event.orderId, emit);
  }

  Future<void> _refreshOrderStatusForSuccess(
    String initialOrderId,
    Emitter<PayState> emit,
  ) async {
    var orderId = initialOrderId;

    while (true) {
      _isOrderRequestInFlight = true;

      try {
        final orderSummary = await _getOrderUsecase.execute(orderId: orderId);

        // Update the order in the current state if we're in success state
        if (state is PaySuccessState) {
          final currentState = state as PaySuccessState;
          // Convert Order to FiatPaymentOrder if needed
          if (orderSummary is FiatPaymentOrder) {
            emit(currentState.copyWith(payOrder: orderSummary));
          } else {
            log.severe(
              error:
                  'Expected FiatPaymentOrder for order $orderId but received ${orderSummary.runtimeType}',
              trace: StackTrace.current,
            );
          }
        }
      } catch (e) {
        log.severe(error: e, trace: StackTrace.current);
        // Don't emit error state for refresh failures in success screen
      } finally {
        _isOrderRequestInFlight = false;
      }

      if (emit.isDone) {
        _pendingOrderStatusUpdateId = null;
        return;
      }
      final pendingOrderId = _pendingOrderStatusUpdateId;
      _pendingOrderStatusUpdateId = null;
      if (pendingOrderId == null) return;
      orderId = pendingOrderId;
    }
  }

  // From Sell: Recalculate fees when UTXOs, RBF or the fee selection changes
  ///
  /// Every emit past an await reads the live state and gives up when it is gone:
  /// this runs across `_getNetworkFeesUsecase` and a PSBT build, so a slow fetch
  /// routinely outlives the screen. Merging into a pre-await snapshot instead
  /// would republish the payment state over whatever replaced it, re-arming
  /// Confirm on a payin already on the wire.
  Future<void> _recalculateFees(Emitter<PayState> emit) async {
    final payPaymentState = _currentPaymentState;
    if (payPaymentState == null) return;
    final wallet = payPaymentState.selectedWallet;
    if (wallet == null) return;

    // The displayed fee belongs to the previous build until this one lands, so
    // drop it and let the row show its calculating state — pairing the old
    // amount with a just-changed fee tier reads as if nothing happened.
    // Restored on failure so the row can't be left calculating forever.
    final previousAbsoluteFees = payPaymentState.absoluteFees;
    emit(payPaymentState.copyWith(absoluteFees: null));

    try {
      final payinAmountSat = ConvertAmount.btcToSats(
        payPaymentState.payOrder.payinAmount,
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
          error: PayError.unexpected(message: 'Failed to recalculate fees: $e'),
        ),
      );
    }
  }

  PayPaymentState? get _currentPaymentState {
    final currentState = state;
    return currentState is PayPaymentState ? currentState : null;
  }

  void _latchBroadcast(Emitter<PayState> emit, String txid) {
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

  Future<void> _completeAfterBroadcast(Emitter<PayState> emit) async {
    await Future.delayed(const Duration(seconds: 5));

    final paymentState = _currentPaymentState;
    if (paymentState == null) return;

    final latestOrder = await _getOrderUsecase.execute(
      orderId: paymentState.payOrder.orderId,
    );
    if (latestOrder is! FiatPaymentOrder) {
      throw const PayError.unexpected(
        message:
            'Expected FiatPaymentOrder but received a different order type',
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

    emit(paymentState.toSuccessState(payOrder: latestOrder));
  }

  void _emitSendPaymentError(Emitter<PayState> emit, PayError error) {
    final current = _currentPaymentState;
    if (current == null || current.isPayinBroadcast) return;
    emit(current.copyWith(error: error, isConfirmingPayment: false));

    final confirmationDeadline = current.payOrder.confirmationDeadline;
    if (confirmationDeadline != null &&
        !confirmationDeadline.isAfter(DateTime.now())) {
      add(const PayEvent.orderRefreshTimePassed());
    }
  }

  /// Address the payin is (or will be) built for. The order's own address keeps
  /// the estimate honest — a build against one of our own addresses can differ
  /// in vsize when the script types differ. Falls back to an own address only
  /// when the order has none yet.
  Future<String> _payinBuildAddress(
    PayPaymentState paymentState,
    Wallet wallet,
  ) async {
    final payinAddress = paymentState.payOrder.bitcoinAddress;
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
  PayPaymentState _clearedFeePreviews(PayPaymentState paymentState) {
    _bitcoinPreviewEpoch++;
    return paymentState.copyWith(feePreviewCache: BitcoinFeePreviewCache.empty);
  }

  /// Payment state while fee selection is still allowed, or null when the event
  /// must be ignored — no payment in flight, a Liquid payin (no fee choice), or
  /// a confirmation already running.
  PayPaymentState? get _feeEditablePaymentState {
    final current = _currentPaymentState;
    if (current == null) return null;
    return current.canEditFees ? current : null;
  }

  Future<void> _onFeeOptionSelected(
    PayFeeOptionSelected event,
    Emitter<PayState> emit,
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
    PayCustomFeeChanged event,
    Emitter<PayState> emit,
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
    PayCustomFeeArmed event,
    Emitter<PayState> emit,
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
    PayCustomFeeDisarmed event,
    Emitter<PayState> emit,
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
    PayCustomFeeFinalized event,
    Emitter<PayState> emit,
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
      await _onCustomFeeChanged(PayCustomFeeChanged(fee), emit);
    } else {
      await _onCustomFeeDisarmed(const PayCustomFeeDisarmed(), emit);
    }
  }

  Future<void> _onCustomFeePreviewRequested(
    PayCustomFeePreviewRequested event,
    Emitter<PayState> emit,
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
      amountSat: ConvertAmount.btcToSats(current.payOrder.payinAmount),
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
    PayPresetFeesPreviewRequested event,
    Emitter<PayState> emit,
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
      amountSat: ConvertAmount.btcToSats(current.payOrder.payinAmount),
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
  // action surface it gets from SendCubit and TransferBloc; the pay flow's own
  // state shape and event dispatch collapse here. Fee state only exists on
  // PayPaymentState, so every other state maps to the neutral defaults (the
  // modal cannot be open from those screens anyway).

  static FeeModalSnapshot _modalSnapshotFromState(PayState s) {
    final payment = s is PayPaymentState ? s : null;
    return FeeModalSnapshot(
      feePresets: payment?.bitcoinFees,
      customFee: payment?.customFee,
      selectedFeeOption: payment?.selectedFeeOption ?? FeeSelection.fastest,
      feePreviewCache: payment?.feePreviewCache ?? BitcoinFeePreviewCache.empty,
      exchangeRate: payment?.exchangeRateEstimate ?? 0.0,
      fiatCurrencyCode: payment?.currency.code ?? '',
      txSize: payment?.bitcoinTxSize ?? 140,
    );
  }

  @override
  FeeModalSnapshot get snapshot => _modalSnapshotFromState(state);

  @override
  Stream<FeeModalSnapshot> get snapshots => stream.map(_modalSnapshotFromState);

  @override
  void requestPresetPreviews() =>
      add(const PayEvent.presetFeesPreviewRequested());

  @override
  void requestCustomFeePreview(NetworkFee fee) =>
      add(PayEvent.customFeePreviewRequested(fee));

  @override
  void armCustomFee(NetworkFee fee) => add(PayEvent.customFeeArmed(fee));

  @override
  void disarmCustomFee() => add(const PayEvent.customFeeDisarmed());

  @override
  void finalizeArmedCustomFee() => add(const PayEvent.customFeeFinalized());

  @override
  void selectFeeOption(FeeSelection selection) =>
      add(PayEvent.feeOptionSelected(selection));

  // From Sell: Manage polling timer
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      add(const PayEvent.pollOrderStatus());
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  Future<void> close() async {
    _stopPolling();
    await _payjoinSubscription?.cancel();
    return super.close();
  }
}
