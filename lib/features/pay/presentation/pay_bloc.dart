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
import 'package:bb_mobile/features/pay/domain/refresh_pay_order_usecase.dart';
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
    on<PaySendPaymentConfirmed>(_onSendPaymentConfirmed);
    on<PayPollOrderStatus>(_onPollOrderStatus);
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
    final walletSelectionState = state.cleanWalletSelectionState;
    if (walletSelectionState == null) {
      log.severe(
        error: 'Expected to be on PayWalletSelectionState',
        trace: StackTrace.current,
      );
      return;
    }

    emit(walletSelectionState.copyWith(isCreatingPayOrder: true));

    int requiredAmountSat;
    final exchangeRateEstimate = await _convertSatsToCurrencyAmountUsecase
        .execute(currencyCode: walletSelectionState.currency.code);

    requiredAmountSat = ConvertAmount.fiatToSats(
      walletSelectionState.amount.amount,
      exchangeRateEstimate,
    );

    if (event.wallet.balanceSat.toInt() < requiredAmountSat) {
      emit(
        walletSelectionState.copyWith(
          error: PayError.unexpected(
            message: 'Insufficient balance. Required: $requiredAmountSat sats',
          ),
        ),
      );
      return;
    }
    int absoluteFees = 0;
    // Carried into the payment state so the confirmation screen can offer the
    // fee modal (#2521): it needs the presets to price the tiles and a vsize to
    // check an absolute custom fee against the relay floor.
    FeeOptions? bitcoinFees;
    int? bitcoinTxSize;
    // This builds a brand-new payment state, with its own order, wallet and
    // empty preview cache. A preview still in flight for the previous one would
    // otherwise land in that cache and price this payin with the last order's
    // fees.
    _bitcoinPreviewEpoch++;
    try {
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
    final paymentState = state.cleanPaymentState;
    if (paymentState == null) {
      log.severe(
        error: 'Expected to be on PayPaymentState',
        trace: StackTrace.current,
      );
      return;
    }

    try {
      final refreshedOrder = await _refreshPayOrderUsecase.execute(
        orderId: paymentState.payOrder.orderId,
      );

      final refreshed = paymentState.copyWith(payOrder: refreshedOrder);
      // A new price lock moves the payin amount, which invalidates every
      // preview built for the old one.
      emit(
        refreshedOrder.payinAmount == paymentState.payOrder.payinAmount
            ? refreshed
            : _clearedFeePreviews(refreshed),
      );
    } on PayError catch (e) {
      emit(paymentState.copyWith(error: e));
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

    emit(payPaymentState.copyWith(isConfirmingPayment: true));
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
        await _broadcastLiquidTransactionUsecase.execute(signedPset);
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
        final signedTx = await _signBitcoinTxUsecase.execute(
          psbt: preparedSend.unsignedPsbt,
          walletId: wallet.id,
        );
        await _broadcastBitcoinTransactionUsecase.execute(
          signedTx.signedPsbt,
          isPsbt: true,
        );
      }
      // 5s delay gives backend time to register the 0 conf
      await Future.delayed(const Duration(seconds: 5));
      final latestOrder = await _getOrderUsecase.execute(
        orderId: payPaymentState.payOrder.orderId,
      );

      if (latestOrder is! FiatPaymentOrder) {
        throw const PayError.unexpected(
          message:
              'Expected FiatPaymentOrder but received a different order type',
        );
      }
      if (state is PayPaymentState) {
        emit((state as PayPaymentState).copyWith(isConfirmingPayment: false));
      }
      emit(payPaymentState.toSuccessState(payOrder: payPaymentState.payOrder));
    } on PrepareLiquidSendException catch (e) {
      emit(
        payPaymentState.copyWith(
          error: PayError.unexpected(message: e.message),
          isConfirmingPayment: false,
        ),
      );
    } on PrepareBitcoinSendException catch (e) {
      emit(
        payPaymentState.copyWith(
          error: PayError.unexpected(message: e.toString()),
          isConfirmingPayment: false,
        ),
      );
    } on SignLiquidTxException catch (e) {
      emit(
        payPaymentState.copyWith(
          error: PayError.unexpected(message: e.toString()),
          isConfirmingPayment: false,
        ),
      );
    } on SignBitcoinTxException catch (e) {
      // Handle PayError and emit error state
      emit(
        payPaymentState.copyWith(
          error: PayError.unexpected(message: e.toString()),
          isConfirmingPayment: false,
        ),
      );
    } catch (e) {
      // Log unexpected errors
      log.severe(error: e, trace: StackTrace.current);
      emit(
        payPaymentState.copyWith(
          error: PayError.unexpected(message: e.toString()),
          isConfirmingPayment: false,
        ),
      );
    }
  }

  // From Sell: Poll for order status
  Future<void> _onPollOrderStatus(
    PayPollOrderStatus event,
    Emitter<PayState> emit,
  ) async {
    if (state is! PayPaymentState) return;

    final payPaymentState = state as PayPaymentState;

    try {
      final latestOrder = await _getOrderUsecase.execute(
        orderId: payPaymentState.payOrder.orderId,
      );

      if (latestOrder is! FiatPaymentOrder) {
        log.severe(
          error:
              'Expected FiatPaymentOrder but received a different order type',
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
          payPaymentState
              .copyWith(payOrder: latestOrder, isPolling: false)
              .toSuccessState(payOrder: latestOrder),
        );
      } else {
        emit(payPaymentState.copyWith(payOrder: latestOrder, isPolling: true));
      }
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
    }
  }

  // From Sell: Toggle RBF and recalculate fees
  Future<void> _onReplaceByFeeChanged(
    PayReplaceByFeeChanged event,
    Emitter<PayState> emit,
  ) async {
    if (state is! PayPaymentState) return;

    final payPaymentState = state as PayPaymentState;
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
    if (state is! PayPaymentState) return;

    final payPaymentState = state as PayPaymentState;
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
      emit(payPaymentState.copyWith(utxos: utxos));
    } catch (e) {
      emit(
        payPaymentState.copyWith(
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
    try {
      final orderSummary = await _getOrderUsecase.execute(
        orderId: event.orderId,
      );

      // Update the order in the current state if we're in success state
      if (state is PaySuccessState) {
        final currentState = state as PaySuccessState;
        // Convert Order to FiatPaymentOrder if needed
        if (orderSummary is FiatPaymentOrder) {
          emit(currentState.copyWith(payOrder: orderSummary));
        }
      }
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      // Don't emit error state for refresh failures in success screen
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
    return paymentState.copyWith(
      feePreviewCache: BitcoinFeePreviewCache.empty,
    );
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
  Future<void> close() {
    _stopPolling();
    return super.close();
  }
}
