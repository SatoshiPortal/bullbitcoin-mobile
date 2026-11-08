import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/bitcoin_price/domain/bitcoin_price_failure.dart';
import 'package:bb_mobile/features/bitcoin_price/domain/usecases/get_price_history_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
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
    required this._getSettingsUsecase,
  }) : super(const PriceChartState());

  final GetPriceHistoryUsecase _getPriceHistoryUsecase;
  final GetSettingsUsecase _getSettingsUsecase;

  Future<void> loadPriceHistory({String? currency}) async {
    emit(state.copyWith(isLoading: true, failure: null));

    final String selectedCurrency;
    try {
      final settings = await _getSettingsUsecase.execute();
      selectedCurrency = currency ?? settings.currencyCode;
    } catch (e) {
      log.warning('loadPriceHistory failed', error: e);
      emit(
        state.copyWith(
          isLoading: false,
          failure: PriceChartUnexpectedFailure(e.toString()),
        ),
      );
      return;
    }

    final history = await _getPriceHistoryUsecase.execute(
      currencyCode: selectedCurrency,
    );
    emit(switch (history) {
      Ok(:final value) when value.length >= _minPoints => state.copyWith(
        isLoading: false,
        prices: value,
        currency: selectedCurrency,
        failure: null,
      ),
      // A single point is no chart.
      Ok() => state.copyWith(
        isLoading: false,
        prices: [],
        currency: selectedCurrency,
        failure: const PriceChartLoadFailure(),
      ),
      Err(:final failure) => state.copyWith(
        isLoading: false,
        prices: [],
        currency: selectedCurrency,
        failure: failure,
      ),
    });
  }

  void selectDataPoint(int? index) {
    emit(state.copyWith(selectedDataPointIndex: index));
  }

  void changeCurrency(String currency) {
    if (state.currency != currency) {
      loadPriceHistory(currency: currency);
    }
  }

  Future<void> showChart([String? currency]) async {
    emit(state.copyWith(showChart: true));
    if (currency != null) {
      loadPriceHistory(currency: currency);
    } else {
      final settings = await _getSettingsUsecase.execute();
      loadPriceHistory(currency: settings.currencyCode);
    }
  }

  void hideChart() {
    emit(state.copyWith(showChart: false, selectedDataPointIndex: null));
  }
}
