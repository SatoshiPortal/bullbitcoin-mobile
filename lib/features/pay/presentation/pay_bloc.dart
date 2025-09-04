import 'dart:async';

import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/cad_biller.dart';
import 'package:bb_mobile/core/exchange/domain/entity/new_recipient.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/errors/pay_error.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/create_fiat_recipient_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/list_cad_billers_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/list_recipients_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart' hide Network;
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/pay/domain/create_pay_order_usecase.dart';
import 'package:bb_mobile/features/pay/domain/refresh_pay_order_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bip21_uri/bip21_uri.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pay_bloc.freezed.dart';
part 'pay_event.dart';
part 'pay_state.dart';

class PayBloc extends Bloc<PayEvent, PayState> {
  PayBloc({
    required GetExchangeUserSummaryUsecase getExchangeUserSummaryUsecase,
    required ListRecipientsUsecase listRecipientsUsecase,
    required CreateFiatRecipientUsecase createFiatRecipientUsecase,
    required ListCadBillersUsecase listCadBillersUsecase,
    required PlacePayOrderUsecase placePayOrderUsecase,
    required RefreshPayOrderUsecase refreshPayOrderUsecase,
    required PrepareBitcoinSendUsecase prepareBitcoinSendUsecase,
    required PrepareLiquidSendUsecase prepareLiquidSendUsecase,
    required SignBitcoinTxUsecase signBitcoinTxUsecase,
    required SignLiquidTxUsecase signLiquidTxUsecase,
    required BroadcastBitcoinTransactionUsecase
    broadcastBitcoinTransactionUsecase,
    required BroadcastLiquidTransactionUsecase
    broadcastLiquidTransactionUsecase,
    required GetNetworkFeesUsecase getNetworkFeesUsecase,
    required CalculateLiquidAbsoluteFeesUsecase
    calculateLiquidAbsoluteFeesUsecase,
    required CalculateBitcoinAbsoluteFeesUsecase
    calculateBitcoinAbsoluteFeesUsecase,
    required ConvertSatsToCurrencyAmountUsecase
    convertSatsToCurrencyAmountUsecase,
    required GetAddressAtIndexUsecase getAddressAtIndexUsecase,
    required GetWalletUtxosUsecase getWalletUtxosUsecase,
    required GetOrderUsecase getOrderUsecase,
  }) : _getExchangeUserSummaryUsecase = getExchangeUserSummaryUsecase,
       _listRecipientsUsecase = listRecipientsUsecase,
       _createFiatRecipientUsecase = createFiatRecipientUsecase,
       _listCadBillersUsecase = listCadBillersUsecase,
       _placePayOrderUsecase = placePayOrderUsecase,
       _refreshPayOrderUsecase = refreshPayOrderUsecase,
       _prepareBitcoinSendUsecase = prepareBitcoinSendUsecase,
       _prepareLiquidSendUsecase = prepareLiquidSendUsecase,
       _signBitcoinTxUsecase = signBitcoinTxUsecase,
       _signLiquidTxUsecase = signLiquidTxUsecase,
       _broadcastBitcoinTransactionUsecase = broadcastBitcoinTransactionUsecase,
       _broadcastLiquidTransactionUsecase = broadcastLiquidTransactionUsecase,
       _getNetworkFeesUsecase = getNetworkFeesUsecase,
       _calculateLiquidAbsoluteFeesUsecase = calculateLiquidAbsoluteFeesUsecase,
       _calculateBitcoinAbsoluteFeesUsecase =
           calculateBitcoinAbsoluteFeesUsecase,
       _convertSatsToCurrencyAmountUsecase = convertSatsToCurrencyAmountUsecase,
       _getAddressAtIndexUsecase = getAddressAtIndexUsecase,
       _getWalletUtxosUsecase = getWalletUtxosUsecase,
       _getOrderUsecase = getOrderUsecase,
       super(const PayInitialState()) {
    on<PayStarted>(_onStarted);
    on<PayAmountInputContinuePressed>(_onAmountInputContinuePressed);
    on<PayNewRecipientAdded>(_onNewRecipientAdded);
    on<PayCreateNewRecipient>(_onCreateNewRecipient);
    on<PayRecipientSelected>(_onRecipientSelected);
    on<PayGetCadBillers>(_onGetCadBillers);
    on<PayWalletSelected>(_onWalletSelected);
    on<PayExternalWalletNetworkSelected>(_onExternalWalletNetworkSelected);
    on<PayOrderRefreshTimePassed>(_onOrderRefreshTimePassed);
    on<PaySendPaymentConfirmed>(_onSendPaymentConfirmed);
    on<PayPollOrderStatus>(_onPollOrderStatus);
    on<PayReplaceByFeeChanged>(_onReplaceByFeeChanged);
    on<PayUtxoSelected>(_onUtxoSelected);
    on<PayLoadUtxos>(_onLoadUtxos);
  }

  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final ListRecipientsUsecase _listRecipientsUsecase;
  final CreateFiatRecipientUsecase _createFiatRecipientUsecase;
  final ListCadBillersUsecase _listCadBillersUsecase;
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
  Timer? _pollingTimer;

  // From Withdraw: Initialize with user summary and recipients
  Future<void> _onStarted(PayStarted event, Emitter<PayState> emit) async {
    try {
      // Reset the initial state to clear any previous exceptions
      PayInitialState initialState;
      if (state is PayInitialState) {
        initialState = state as PayInitialState;
      } else {
        initialState = const PayInitialState();
      }
      emit(
        initialState.copyWith(
          apiKeyException: null,
          getUserSummaryException: null,
          listRecipientsException: null,
        ),
      );

      final (userSummary, recipients) =
          await (
            _getExchangeUserSummaryUsecase.execute(),
            _listRecipientsUsecase.execute(fiatOnly: true),
          ).wait;

      emit(
        initialState.toAmountInputState(
          userSummary: userSummary,
          recipients: recipients,
        ),
      );
    } on ApiKeyException catch (e) {
      emit(PayState.initial(apiKeyException: e));
    } on GetExchangeUserSummaryException catch (e) {
      emit(PayState.initial(getUserSummaryException: e));
    } on ListRecipientsException catch (e) {
      emit(PayState.initial(listRecipientsException: e));
    }
  }

  // From Withdraw: Parse amount and go to recipient input
  Future<void> _onAmountInputContinuePressed(
    PayAmountInputContinuePressed event,
    Emitter<PayState> emit,
  ) async {
    // We should be on a PayAmountInputState or PayRecipientInputState and
    //  return to a clean PayAmountInputState state to change the amount
    final amountInputState = state.cleanPayAmountInputState;
    if (amountInputState == null) {
      // Unexpected state, do nothing
      log.severe('Expected to be on PayAmountInputState but on: $state');
      return;
    }
    emit(amountInputState);

    final amount = FiatAmount(double.parse(event.amountInput));

    emit(
      amountInputState.toRecipientInputState(
        amount: amount,
        currency: event.fiatCurrency,
      ),
    );
  }

  // From Withdraw: Add new recipient form
  Future<void> _onNewRecipientAdded(
    PayNewRecipientAdded event,
    Emitter<PayState> emit,
  ) async {
    // TODO
  }

  // From Withdraw: Create new recipient and create pay order
  Future<void> _onCreateNewRecipient(
    PayCreateNewRecipient event,
    Emitter<PayState> emit,
  ) async {
    log.info('🚀 _onCreateNewRecipient called');
    log.info('📝 New recipient from event: ${event.newRecipient}');

    if (state is PayRecipientInputState) {
      final currentState = state as PayRecipientInputState;

      // Set loading state for new recipient creation
      emit(currentState.copyWith(isCreatingNewRecipient: true));

      // Use the recipient from the event directly
      final newRecipient = event.newRecipient;
      log.info('🏭 Executing createFiatRecipientUsecase...');
      try {
        final createdRecipient = await _createFiatRecipientUsecase.execute(
          newRecipient,
        );
        log.info(
          '✅ Recipient created successfully: ${createdRecipient.recipientId}',
        );

        // Add the new recipient to the list and update state
        final updatedRecipients = [
          ...currentState.recipients,
          createdRecipient,
        ];

        // Update state with the new recipient list and clear the newRecipient
        final updatedState = currentState.copyWith(
          recipients: updatedRecipients,
          newRecipient: null,
          isCreatingNewRecipient: false,
        );
        emit(updatedState);
        log.info('✅ State updated with new recipient list');

        // Transition to wallet selection state with the created recipient
        // No order creation yet - we need to know the network first
        emit(updatedState.toWalletSelectionState(recipient: createdRecipient));
        log.info('✅ Transitioned to wallet selection state');
      } catch (e) {
        log.severe('Error creating new recipient: $e');
        emit(
          currentState.copyWith(
            error: PayError.unexpected(
              message: 'Failed to create recipient: $e',
            ),
            isCreatingNewRecipient: false, // Reset loading state on error
          ),
        );
      }
    }
  }

  // From Withdraw: Select existing recipient and create pay order
  Future<void> _onRecipientSelected(
    PayRecipientSelected event,
    Emitter<PayState> emit,
  ) async {
    // We should be on a PayRecipientInputState or PayWalletSelectionState and
    //  return to a clean PayRecipientInputState to change the recipient
    PayRecipientInputState recipientInputState;
    switch (state) {
      case PayRecipientInputState _:
        recipientInputState = state as PayRecipientInputState;
      case final PayWalletSelectionState walletSelectionState:
        recipientInputState = walletSelectionState.toRecipientInputState();
      default:
        // Unexpected state, do nothing
        return;
    }
    emit(recipientInputState.copyWith(error: null));

    // Just transition to wallet selection - no order creation yet
    // We need to know the network (from wallet selection) first
    final recipient = event.recipient;
    emit(recipientInputState.toWalletSelectionState(recipient: recipient));
  }

  // From Withdraw: Get CAD billers for search
  Future<void> _onGetCadBillers(
    PayGetCadBillers event,
    Emitter<PayState> emit,
  ) async {
    if (state is PayRecipientInputState) {
      final currentState = state as PayRecipientInputState;

      // Only search if search term has at least 3 characters
      if (event.searchTerm.length < 3) {
        return;
      }

      emit(currentState.copyWith(isLoadingCadBillers: true));

      try {
        final cadBillers = await _listCadBillersUsecase.execute(
          searchTerm: event.searchTerm,
        );
        emit(
          currentState.copyWith(
            cadBillers: cadBillers,
            isLoadingCadBillers: false,
          ),
        );
      } catch (e) {
        log.severe('Error fetching CAD billers: $e');
        emit(
          currentState.copyWith(
            isLoadingCadBillers: false,
            error: PayError.unexpected(message: 'Failed to load billers: $e'),
          ),
        );
      }
    }
  }

  // From Sell: Select internal wallet, calculate fees, create pay order
  Future<void> _onWalletSelected(
    PayWalletSelected event,
    Emitter<PayState> emit,
  ) async {
    final walletSelectionState = state.toCleanWalletSelectionState;
    if (walletSelectionState == null) {
      log.severe('Expected to be on PayWalletSelectionState but on: $state');
      return;
    }
    emit(walletSelectionState.copyWith(isCreatingPayOrder: true, error: null));

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
    try {
      final dummyAddressForFeeCalculation = await _getAddressAtIndexUsecase
          .execute(walletId: event.wallet.id, index: 0);

      if (event.wallet.isLiquid) {
        final pset = await _prepareLiquidSendUsecase.execute(
          walletId: event.wallet.id,
          address: dummyAddressForFeeCalculation.address,
          amountSat: requiredAmountSat,
          networkFee: const NetworkFee.relative(0.1),
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
          feeRate: fastestFee.value as double,
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
        recipientId: walletSelectionState.recipient.recipientId,
        network:
            event.wallet.isLiquid
                ? OrderBitcoinNetwork.liquid
                : OrderBitcoinNetwork.bitcoin,
      );

      log.info('createdPayOrder (internal wallet): $createdPayOrder');
      log.info(
        'createdPayOrder.bitcoinAddress: ${createdPayOrder.bitcoinAddress}',
      );
      log.info(
        'createdPayOrder.liquidAddress: ${createdPayOrder.liquidAddress}',
      );
      log.info(
        'createdPayOrder.lightningInvoice: ${createdPayOrder.lightningInvoice}',
      );
      log.info('createdPayOrder.payinMethod: ${createdPayOrder.payinMethod}');

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
      log.severe('Unexpected error in PayBloc: $e');
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
    // We should be on a PayWalletSelection or PayPaymentState and return
    //  to a clean PayWalletSelectionState state
    final walletSelectionState = state.toCleanWalletSelectionState;
    if (walletSelectionState == null) {
      log.severe('Expected to be on PayWalletSelectionState but on: $state');
      return;
    }
    emit(walletSelectionState.copyWith(isCreatingPayOrder: true));

    try {
      final createdPayOrder = await _placePayOrderUsecase.execute(
        orderAmount: walletSelectionState.amount,
        recipientId: walletSelectionState.recipient.recipientId,
        network: event.network,
      );

      log.info('createdPayOrder: $createdPayOrder');
      log.info(
        'createdPayOrder.bitcoinAddress: ${createdPayOrder.bitcoinAddress}',
      );
      log.info(
        'createdPayOrder.liquidAddress: ${createdPayOrder.liquidAddress}',
      );
      log.info(
        'createdPayOrder.lightningInvoice: ${createdPayOrder.lightningInvoice}',
      );
      log.info('createdPayOrder.payinMethod: ${createdPayOrder.payinMethod}');
      // Proceed to payment state
      emit(
        walletSelectionState.toReceivePaymentState(payOrder: createdPayOrder),
      );
      _startPolling();
    } on PayError catch (e) {
      emit(walletSelectionState.copyWith(error: e));
    } catch (e) {
      // Log unexpected errors
      log.severe('Unexpected error in PayBloc: $e');
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
    final paymentState = state.toCleanPaymentState;
    if (paymentState == null) {
      log.severe('Expected to be on PayPaymentState but on: $state');
      return;
    }

    try {
      final refreshedOrder = await _refreshPayOrderUsecase.execute(
        orderId: paymentState.payOrder.orderId,
      );

      emit(paymentState.copyWith(payOrder: refreshedOrder));
    } on PayError catch (e) {
      emit(paymentState.copyWith(error: e));
    } catch (e) {
      log.severe('Unexpected error in PayBloc: $e');
    }
  }

  // From Sell: Send payment for internal wallets
  Future<void> _onSendPaymentConfirmed(
    PaySendPaymentConfirmed event,
    Emitter<PayState> emit,
  ) async {
    // We should be on a PayPaymentState
    final payPaymentState = state.toCleanPaymentState;
    if (payPaymentState == null) {
      log.severe('Expected to be on PayPaymentState but on: $state');
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
          networkFee: const NetworkFee.relative(0.1),
        );
        final signedPset = await _signLiquidTxUsecase.execute(
          pset: pset,
          walletId: wallet.id,
        );
        await _broadcastLiquidTransactionUsecase.execute(signedPset);
      } else {
        final absoluteFees = payPaymentState.absoluteFees;
        if (absoluteFees == null) {
          throw const PayError.unexpected(
            message: 'Transaction fees not calculated. Please try again.',
          );
        }
        final bitcoinFees = await _getNetworkFeesUsecase.execute(
          isLiquid: false,
        );
        final fastestFee = bitcoinFees.fastest;

        final preparedSend = await _prepareBitcoinSendUsecase.execute(
          walletId: wallet.id,
          address: payPaymentState.payOrder.bitcoinAddress!,
          amountSat: payinAmountSat,
          networkFee: NetworkFee.absolute(absoluteFees),
          selectedInputs:
              payPaymentState.selectedUtxos.isNotEmpty
                  ? payPaymentState.selectedUtxos
                  : null,
          replaceByFee: payPaymentState.replaceByFee,
        );
        final absoluteFeesUpdated = await _calculateBitcoinAbsoluteFeesUsecase
            .execute(
              psbt: preparedSend.unsignedPsbt,
              feeRate: fastestFee.value as double,
            );
        emit(payPaymentState.copyWith(absoluteFees: absoluteFeesUpdated));
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
      log.severe('Unexpected error in PayBloc: $e');
      emit(
        payPaymentState.copyWith(
          error: PayError.unexpected(message: e.toString()),
          isConfirmingPayment: false,
        ),
      );
    } finally {
      if (state is PayPaymentState) {
        emit((state as PayPaymentState).copyWith(isConfirmingPayment: false));
      }
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
          'Expected FiatPaymentOrder but received a different order type',
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
      log.severe('Error polling order status: $e');
    }
  }

  // From Sell: Toggle RBF and recalculate fees
  Future<void> _onReplaceByFeeChanged(
    PayReplaceByFeeChanged event,
    Emitter<PayState> emit,
  ) async {
    if (state is! PayPaymentState) return;

    final payPaymentState = state as PayPaymentState;
    emit(payPaymentState.copyWith(replaceByFee: event.replaceByFee));
    await _recalculateFees(emit);
  }

  // From Sell: Select/deselect UTXOs
  Future<void> _onUtxoSelected(
    PayUtxoSelected event,
    Emitter<PayState> emit,
  ) async {
    if (state is! PayPaymentState) return;

    final payPaymentState = state as PayPaymentState;
    final selectedUtxos = List.of(payPaymentState.selectedUtxos);

    if (selectedUtxos.contains(event.utxo)) {
      selectedUtxos.remove(event.utxo);
    } else {
      selectedUtxos.add(event.utxo);
    }

    emit(payPaymentState.copyWith(selectedUtxos: selectedUtxos));
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

  // From Sell: Recalculate fees when UTXOs or RBF changes
  Future<void> _recalculateFees(Emitter<PayState> emit) async {
    if (state is! PayPaymentState) return;

    final payPaymentState = state as PayPaymentState;
    final wallet = payPaymentState.selectedWallet;
    if (wallet == null) return;

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
          networkFee: const NetworkFee.relative(0.1),
        );
        final absoluteFees = await _calculateLiquidAbsoluteFeesUsecase.execute(
          pset: pset,
        );
        emit(payPaymentState.copyWith(absoluteFees: absoluteFees));
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
          selectedInputs:
              payPaymentState.selectedUtxos.isNotEmpty
                  ? payPaymentState.selectedUtxos
                  : null,
          replaceByFee: payPaymentState.replaceByFee,
        );
        final absoluteFees = await _calculateBitcoinAbsoluteFeesUsecase.execute(
          psbt: preparedSend.unsignedPsbt,
          feeRate: fastestFee.value as double,
        );
        emit(payPaymentState.copyWith(absoluteFees: absoluteFees));
      }
    } catch (e) {
      emit(
        payPaymentState.copyWith(
          error: PayError.unexpected(message: 'Failed to recalculate fees: $e'),
        ),
      );
    }
  }

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
