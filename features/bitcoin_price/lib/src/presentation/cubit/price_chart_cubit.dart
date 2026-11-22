import 'package:bitcoin_price/src/domain/usecases/read_price_currency_usecase.dart';
import 'package:bitcoin_price/src/domain/bitcoin_price_failure.dart';
import 'package:bitcoin_price/src/domain/usecases/get_price_history_usecase.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:primitives/primitives.dart';

part 'price_chart_cubit.freezed.dart';
part 'price_chart_state.dart';

class PriceChartCubit extends Cubit<PriceChartState> {
  /// A line needs two points: with fewer, there is no chart to show.
  static const _minPoints = 2;

  PriceChartCubit({
    required this._getPriceHistoryUsecase,
    required this._readPriceCurrencyUsecase,
  }) : super(const PriceChartState());

  final GetPriceHistoryUsecase _getPriceHistoryUsecase;
  final ReadPriceCurrencyUsecase _readPriceCurrencyUsecase;

  int _request = 0;

  Future<Result<void, BitcoinPriceFailure>> loadPriceHistory({
    String? currency,
  }) async {
    final request = ++_request;
    emit(state.copyWith(isLoading: true, failure: null));

    final currencyResult = currency == null
        ? await _readPriceCurrencyUsecase.execute()
        : Ok<String, BitcoinPriceFailure>(currency);
    final String selectedCurrency;
    switch (currencyResult) {
      case Ok(:final value):
        selectedCurrency = value;
      case Err(:final failure):
        if (!isClosed && request == _request) {
          emit(state.copyWith(isLoading: false, failure: failure));
        }
        return Err(failure);
    }

    if (isClosed || request != _request) {
      return const Err(PriceChartLoadFailure());
    }

    final history = await _getPriceHistoryUsecase.execute(
      currencyCode: selectedCurrency,
    );
    final chart = switch (history) {
      Ok(:final value) when value.length < _minPoints =>
        const Err<List<PricePoint>, BitcoinPriceFailure>(
          PriceChartLoadFailure(),
        ),
      _ => history,
    };
    if (!isClosed && request == _request) {
      emit(switch (chart) {
        Ok(:final value) => state.copyWith(
          isLoading: false,
          prices: value,
          currency: selectedCurrency,
          failure: null,
        ),
        Err(:final failure) => state.copyWith(
          isLoading: false,
          prices: [],
          currency: selectedCurrency,
          failure: failure,
        ),
      });
    }
    return chart.map<void>((_) {});
  }

  void selectDataPoint(int? index) {
    emit(state.copyWith(selectedDataPointIndex: index));
  }

  void changeCurrency(String currency) {
    if (state.currency != currency) {
      loadPriceHistory(currency: currency);
    }
  }

  Future<Result<void, BitcoinPriceFailure>> showChart([String? currency]) {
    emit(state.copyWith(showChart: true));
    return loadPriceHistory(currency: currency);
  }

  void hideChart() {
    emit(state.copyWith(showChart: false, selectedDataPointIndex: null));
  }
}
