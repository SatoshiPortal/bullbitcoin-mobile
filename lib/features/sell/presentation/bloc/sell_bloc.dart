import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/errors/sell_error.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/sell/domain/create_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/refresh_sell_order_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sell_event.dart';
part 'sell_state.dart';
part 'sell_bloc.freezed.dart';

class SellBloc extends Bloc<SellEvent, SellState> {
  SellBloc({
    required GetExchangeUserSummaryUsecase getExchangeUserSummaryUsecase,
    required GetSettingsUsecase getSettingsUsecase,
    required CreateSellOrderUsecase createSellOrderUsecase,
    required RefreshSellOrderUsecase refreshSellOrderUsecase,
    required PrepareBitcoinSendUsecase prepareBitcoinSendUsecase,
    required PrepareLiquidSendUsecase prepareLiquidSendUsecase,
    required SignBitcoinTxUsecase signBitcoinTxUsecase,
    required SignLiquidTxUsecase signLiquidTxUsecase,
    required BroadcastBitcoinTransactionUsecase
    broadcastBitcoinTransactionUsecase,
    required BroadcastLiquidTransactionUsecase
    broadcastLiquidTransactionUsecase,
  }) : _getExchangeUserSummaryUsecase = getExchangeUserSummaryUsecase,
       _getSettingsUsecase = getSettingsUsecase,
       _createSellOrderUsecase = createSellOrderUsecase,
       _refreshSellOrderUsecase = refreshSellOrderUsecase,
       _prepareBitcoinSendUsecase = prepareBitcoinSendUsecase,
       _prepareLiquidSendUsecase = prepareLiquidSendUsecase,
       _signBitcoinTxUsecase = signBitcoinTxUsecase,
       _signLiquidTxUsecase = signLiquidTxUsecase,
       _broadcastBitcoinTransactionUsecase = broadcastBitcoinTransactionUsecase,
       _broadcastLiquidTransactionUsecase = broadcastLiquidTransactionUsecase,
       super(const SellState.initial()) {
    on<SellStarted>(_onStarted);
    on<SellAmountInputContinuePressed>(_onAmountInputContinuePressed);
    on<SellWalletSelected>(_onWalletSelected);
    on<SellExternalWalletNetworkSelected>(_onExternalWalletNetworkSelected);
    on<SellOrderRefreshTimePassed>(_onOrderRefreshTimePassed);
    on<SellSendPaymentConfirmed>(_onSendPaymentConfirmed);
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
    } on ApiKeyException catch (e) {
      emit(SellState.initial(apiKeyException: e));
    } on GetExchangeUserSummaryException catch (e) {
      emit(SellState.initial(getUserSummaryException: e));
    }
  }

  Future<void> _onAmountInputContinuePressed(
    SellAmountInputContinuePressed event,
    Emitter<SellState> emit,
  ) async {
    // We should be on a SellAmountInputState or SellWalletSelectionState and
    //  return to a clean SellWalletSelectionState state
    SellAmountInputState amountInputState;
    switch (state) {
      case SellAmountInputState _:
        amountInputState = state as SellAmountInputState;
      case final SellWalletSelectionState walletSelectionState:
        amountInputState = walletSelectionState.toAmountInputState();
      default:
        // Unexpected state, do nothing
        return;
    }
    emit(amountInputState);

    OrderAmount orderAmount;
    if (event.isFiatCurrencyInput) {
      orderAmount = FiatAmount(double.parse(event.amountInput));
    } else {
      final amountBtc =
          amountInputState.bitcoinUnit == BitcoinUnit.sats
              ? double.parse(event.amountInput)
              : int.parse(event.amountInput) / 1e8;
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
    // We should be on a SellWalletSelection or SellPaymentState and return
    //  to a clean SellWalletSelectionState state
    SellWalletSelectionState walletSelectionState;
    switch (state) {
      case SellWalletSelectionState _:
        walletSelectionState = state as SellWalletSelectionState;
      case final SellPaymentState paymentState:
        walletSelectionState = paymentState.toWalletSelectionState();
      default:
        // Unexpected state, do nothing
        return;
    }
    emit(walletSelectionState.copyWith(isCreatingSellOrder: true, error: null));

    // Now we can create the sell order with the selected wallet
    try {
      final createdSellOrder = await _createSellOrderUsecase.execute(
        orderAmount: walletSelectionState.orderAmount,
        currency: walletSelectionState.fiatCurrency,
        isLiquid: event.wallet.isLiquid,
      );

      // Proceed to confirmation state
      emit(
        walletSelectionState.toSendPaymentState(
          selectedWallet: event.wallet,
          createdSellOrder: createdSellOrder,
        ),
      );
    } on SellError catch (e) {
      // Handle SellError and emit error state
      emit(walletSelectionState.copyWith(error: e));
    } catch (e) {
      // Log unexpected errors
      log.severe('Unexpected error in SellBloc: $e');
    } finally {
      // Reset the isCreatingSellOrder flag if any error occured
      if (state is SellWalletSelectionState) {
        // Reset the isCreatingSellOrder flag
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
    SellWalletSelectionState walletSelectionState;
    switch (state) {
      case SellWalletSelectionState _:
        walletSelectionState = state as SellWalletSelectionState;
      case final SellPaymentState paymentState:
        walletSelectionState = paymentState.toWalletSelectionState();
      default:
        // Unexpected state, do nothing
        return;
    }
    emit(walletSelectionState.copyWith(isCreatingSellOrder: true, error: null));

    // Now we can create the sell order with the selected wallet
    try {
      final createdSellOrder = await _createSellOrderUsecase.execute(
        orderAmount: walletSelectionState.orderAmount,
        currency: walletSelectionState.fiatCurrency,
        isLiquid: event.network == OrderPaymentMethod.liquid,
      );

      // Proceed to confirmation state
      emit(
        walletSelectionState.toReceivePaymentState(
          createdSellOrder: createdSellOrder,
        ),
      );
    } on SellError catch (e) {
      // Handle SellError and emit error state
      emit(walletSelectionState.copyWith(error: e));
    } catch (e) {
      // Log unexpected errors
      log.severe('Unexpected error in SellBloc: $e');
    } finally {
      // Reset the isCreatingSellOrder flag if any error occured
      if (state is SellWalletSelectionState) {
        // Reset the isCreatingSellOrder flag
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
    SellPaymentState paymentState;
    switch (state) {
      case SellPaymentState _:
        paymentState = state as SellPaymentState;
      default:
        // Unexpected state, do nothing
        return;
    }
    emit(paymentState.copyWith(error: null));

    try {
      final refreshedOrder = await _refreshSellOrderUsecase.execute(
        orderId: paymentState.sellOrder.orderId,
      );

      // Update the state with the refreshed order
      emit(paymentState.copyWith(sellOrder: refreshedOrder));
    } on SellError catch (e) {
      // Handle SellError and emit error state
      emit(paymentState.copyWith(error: e));
    } catch (e) {
      // Log unexpected errors
      log.severe('Unexpected error in SellBloc: $e');
    }
  }

  Future<void> _onSendPaymentConfirmed(
    SellSendPaymentConfirmed event,
    Emitter<SellState> emit,
  ) async {
    // We should be on a SellPaymentState
    SellPaymentState sellPaymentState;
    switch (state) {
      case SellPaymentState _:
        sellPaymentState = state as SellPaymentState;
      default:
        // Unexpected state, do nothing
        return;
    }

    emit(sellPaymentState.copyWith(isConfirmingPayment: true, error: null));
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
          // TODO: use the real fee
          networkFee: const NetworkFee.relative(0.1),
        );
        final signedPset = await _signLiquidTxUsecase.execute(
          pset: pset,
          walletId: wallet.id,
        );
        await _broadcastLiquidTransactionUsecase.execute(signedPset);
      } else {
        final preparedSend = await _prepareBitcoinSendUsecase.execute(
          walletId: wallet.id,
          address: sellPaymentState.sellOrder.bitcoinAddress!,
          amountSat: payinAmountSat,
          // TODO: use the real fee
          networkFee: const NetworkFee.absolute(200),
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

      emit(sellPaymentState.toInProgressState());
    } on SellError catch (e) {
      // Handle SellError and emit error state
      emit(sellPaymentState.copyWith(error: e));
    } catch (e) {
      // Log unexpected errors
      log.severe('Unexpected error in SellBloc: $e');
    } finally {
      // Reset the isConfirmingPayment flag if any error occured
      if (state is SellPaymentState) {
        emit((state as SellPaymentState).copyWith(isConfirmingPayment: false));
      }
    }
  }
}
