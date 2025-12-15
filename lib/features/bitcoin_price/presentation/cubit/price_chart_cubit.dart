import 'package:bb_mobile/core_deprecated/exchange/domain/entity/rate.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/usecases/get_price_history_usecase.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/usecases/refresh_price_history_usecase.dart';
import 'package:bb_mobile/core_deprecated/settings/domain/get_settings_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'price_chart_cubit.freezed.dart';
part 'price_chart_state.dart';

class PriceChartCubit extends Cubit<PriceChartState> {
  PriceChartCubit({
    required GetPriceHistoryUsecase getPriceHistoryUsecase,
    required RefreshPriceHistoryUsecase refreshPriceHistoryUsecase,
    required GetSettingsUsecase getSettingsUsecase,
  }) : _getPriceHistoryUsecase = getPriceHistoryUsecase,
       _refreshPriceHistoryUsecase = refreshPriceHistoryUsecase,
       _getSettingsUsecase = getSettingsUsecase,
       super(const PriceChartState());

  final GetPriceHistoryUsecase _getPriceHistoryUsecase;
  final RefreshPriceHistoryUsecase _refreshPriceHistoryUsecase;
  final GetSettingsUsecase _getSettingsUsecase;

  Future<void> loadPriceHistory({
    String? currency,
    RateTimelineInterval? interval,
  }) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      final settings = await _getSettingsUsecase.execute();
      final selectedCurrency = currency ?? settings.currencyCode;

      final localDayPrices = await _getPriceHistoryUsecase.execute(
        fromCurrency: 'BTC',
        toCurrency: selectedCurrency,
        interval: RateTimelineInterval.day,
      );

      final localFifteenPrices = await _getPriceHistoryUsecase.execute(
        fromCurrency: 'BTC',
        toCurrency: selectedCurrency,
        interval: RateTimelineInterval.fifteen,
      );

      final localAllPrices = <Rate>[];
      if (localFifteenPrices.isNotEmpty) {
        localAllPrices.addAll(localFifteenPrices);
      }
      if (localDayPrices.isNotEmpty) {
        localAllPrices.addAll(localDayPrices);
      }

      localAllPrices.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      if (localAllPrices.isNotEmpty) {
        emit(
          state.copyWith(
            isLoading: false,
            prices: localAllPrices,
            currency: selectedCurrency,
            error: null,
          ),
        );
      }

      final refreshedDayPrices = await _refreshPriceHistoryUsecase.execute(
        fromCurrency: 'BTC',
        toCurrency: selectedCurrency,
        interval: RateTimelineInterval.day,
      );

      final refreshedFifteenPrices = await _refreshPriceHistoryUsecase.execute(
        fromCurrency: 'BTC',
        toCurrency: selectedCurrency,
        interval: RateTimelineInterval.fifteen,
      );

      final refreshedAllPrices = <Rate>[];
      if (refreshedFifteenPrices.isNotEmpty) {
        refreshedAllPrices.addAll(refreshedFifteenPrices);
      }
      if (refreshedDayPrices.isNotEmpty) {
        refreshedAllPrices.addAll(refreshedDayPrices);
      }

      refreshedAllPrices.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      if (refreshedAllPrices.isNotEmpty || localAllPrices.isEmpty) {
        emit(
          state.copyWith(
            isLoading: false,
            prices: refreshedAllPrices,
            currency: selectedCurrency,
            error: null,
          ),
        );
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e));
    }
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
