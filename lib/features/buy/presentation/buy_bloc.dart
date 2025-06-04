import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'buy_event.dart';
part 'buy_state.dart';

part 'buy_bloc.freezed.dart';

class BuyBloc extends Bloc<BuyEvent, BuyState> {
  BuyBloc({
    required GetExchangeUserSummaryUsecase getExchangeUserSummaryUsecase,
  }) : _getExchangeUserSummaryUsecase = getExchangeUserSummaryUsecase,
       super(const BuyState()) {
    on<_BuyStarted>(_onStarted);
  }

  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;

  Future<void> _onStarted(_BuyStarted event, Emitter<BuyState> emit) async {
    try {
      final summary = await _getExchangeUserSummaryUsecase.execute();

      if (summary == null) {
        emit(state.copyWith(balances: {})); // Handle null case
        return;
      }

      final Map<String, double> balances = {};
      for (final balance in summary.balances) {
        balances[balance.currencyCode] = balance.amount;
      }

      emit(state.copyWith(balances: balances));
    } catch (e) {
      // TODO:  Handle error appropriately, log it and emit an error state
      debugPrint('Error fetching user summary: $e');
    }
  }
}
