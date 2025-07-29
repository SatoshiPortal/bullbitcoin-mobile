import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/sell/domain/sell_error.dart';
import 'package:bb_mobile/features/sell/domain/usecases/create_sell_order_usecase.dart';
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
  }) : _getExchangeUserSummaryUsecase = getExchangeUserSummaryUsecase,
       _getSettingsUsecase = getSettingsUsecase,
       _createSellOrderUsecase = createSellOrderUsecase,
       super(const SellState.initial()) {
    on<SellStarted>(_onStarted);
    on<SellAmountConfirmed>(_onAmountConfirmed);
  }

  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final GetSettingsUsecase _getSettingsUsecase;
  // ignore: unused_field
  final CreateSellOrderUsecase _createSellOrderUsecase;

  Future<void> _onStarted(SellStarted event, Emitter<SellState> emit) async {
    try {
      final userSummary = await _getExchangeUserSummaryUsecase.execute();
      final settings = await _getSettingsUsecase.execute();

      emit(
        SellState.amount(
          userSummary: userSummary,
          bitcoinUnit: settings.bitcoinUnit,
          userRate: 0.0,
        ),
      );
    } on ApiKeyException catch (e) {
      emit(SellState.initial(apiKeyException: e));
    } on GetExchangeUserSummaryException catch (e) {
      emit(SellState.initial(getUserSummaryException: e));
    }
  }

  Future<void> _onAmountConfirmed(
    SellAmountConfirmed event,
    Emitter<SellState> emit,
  ) async {
    // We should start from a SellAmountState or convert from SellPayoutMethodState
    SellAmountState amountState;
    switch (state) {
      case SellAmountState _:
        amountState = state as SellAmountState;
      case final SellPayoutMethodState payoutMethodState:
        amountState = payoutMethodState.toAmountState();
      default:
        // Unexpected state, do nothing
        return;
    }
    // Reset errors and set confirming state
    emit(amountState.copyWith(isConfirmingAmount: true));

    OrderAmount orderAmount;
    if (event.isFiatCurrencyInput) {
      orderAmount = FiatAmount(double.parse(event.amountInput));
    } else {
      final amountBtc =
          amountState.bitcoinUnit == BitcoinUnit.sats
              ? double.parse(event.amountInput)
              : int.parse(event.amountInput) / 1e8;
      orderAmount = BitcoinAmount(amountBtc);
    }

    emit(
      amountState.toPayoutMethodState(
        orderAmount: orderAmount,
        fiatCurrency: event.fiatCurrency,
      ),
    );
  }
}
