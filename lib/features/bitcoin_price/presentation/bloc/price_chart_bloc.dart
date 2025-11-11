import 'package:bb_mobile/core/exchange/domain/entity/rate_history.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_all_intervals_rate_history_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_index_rate_history_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'price_chart_bloc.freezed.dart';
part 'price_chart_event.dart';
part 'price_chart_state.dart';

class PriceChartBloc extends Bloc<PriceChartEvent, PriceChartState> {
  PriceChartBloc({
    required GetIndexRateHistoryUsecase getIndexRateHistoryUsecase,
    required GetAllIntervalsRateHistoryUsecase
    getAllIntervalsRateHistoryUsecase,
    required GetSettingsUsecase getSettingsUsecase,
  }) : _getIndexRateHistoryUsecase = getIndexRateHistoryUsecase,
       _getAllIntervalsRateHistoryUsecase = getAllIntervalsRateHistoryUsecase,
       _getSettingsUsecase = getSettingsUsecase,
       super(const PriceChartState()) {
    on<PriceChartStarted>(_onStarted);
    on<PriceChartIntervalChanged>(_onIntervalChanged);
    on<PriceChartDataPointSelected>(_onDataPointSelected);
    on<PriceChartClosed>(_onClosed);
    on<PriceChartFetchAllIntervals>(_onFetchAllIntervals);
  }

  final GetIndexRateHistoryUsecase _getIndexRateHistoryUsecase;
  final GetAllIntervalsRateHistoryUsecase _getAllIntervalsRateHistoryUsecase;
  final GetSettingsUsecase _getSettingsUsecase;

  Future<void> _onStarted(
    PriceChartStarted event,
    Emitter<PriceChartState> emit,
  ) async {
    try {
      final settings = await _getSettingsUsecase.execute();
      final currency = event.currency ?? settings.currencyCode;
      final interval = event.interval ?? RateTimelineInterval.hour;

      final fromDate = _getFromDateForInterval(interval);
      final toDate = DateTime.now().toUtc();

      final rateHistory = await _getIndexRateHistoryUsecase.execute(
        fromCurrency: currency,
        toCurrency: 'BTC',
        interval: interval.value,
        fromDate: fromDate,
        toDate: toDate,
      );

      emit(
        state.copyWith(
          currency: currency,
          selectedInterval: interval,
          rateHistory: rateHistory,
          isLoading: false,
        ),
      );

      // Only fetch all intervals once on app startup
      if (!state.hasFetchedAllIntervals) {
        add(PriceChartFetchAllIntervals(currency: currency));
      }
    } catch (e) {
      log.severe('[PriceChartBloc] _onStarted error: $e');
      emit(state.copyWith(error: e, isLoading: false));
    }
  }

  Future<void> _onIntervalChanged(
    PriceChartIntervalChanged event,
    Emitter<PriceChartState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true, selectedDataPointIndex: null));

      final currency = state.currency;
      if (currency == null) return;

      // Use cached data if available
      final allIntervalsData = state.allIntervalsData;
      if (allIntervalsData != null &&
          allIntervalsData.containsKey(event.interval.value)) {
        final cachedRateHistory = allIntervalsData[event.interval.value]!;
        emit(
          state.copyWith(
            selectedInterval: event.interval,
            rateHistory: cachedRateHistory,
            isLoading: false,
            selectedDataPointIndex: null,
          ),
        );
        return;
      }

      // Otherwise fetch from API (incremental update)
      final fromDate = _getFromDateForInterval(event.interval);
      final toDate = DateTime.now().toUtc();

      final rateHistory = await _getIndexRateHistoryUsecase.execute(
        fromCurrency: currency,
        toCurrency: 'BTC',
        interval: event.interval.value,
        fromDate: fromDate,
        toDate: toDate,
      );

      emit(
        state.copyWith(
          selectedInterval: event.interval,
          rateHistory: rateHistory,
          isLoading: false,
          selectedDataPointIndex: null,
        ),
      );
    } catch (e) {
      log.severe('[PriceChartBloc] _onIntervalChanged error: $e');
      emit(state.copyWith(error: e, isLoading: false));
    }
  }

  void _onDataPointSelected(
    PriceChartDataPointSelected event,
    Emitter<PriceChartState> emit,
  ) {
    emit(state.copyWith(selectedDataPointIndex: event.index));
  }

  void _onClosed(PriceChartClosed event, Emitter<PriceChartState> emit) {
    emit(const PriceChartState());
  }

  Future<void> _onFetchAllIntervals(
    PriceChartFetchAllIntervals event,
    Emitter<PriceChartState> emit,
  ) async {
    try {
      final currency = event.currency;
      final fromDate =
          DateTime.now().subtract(const Duration(days: 365)).toUtc();
      final toDate = DateTime.now().toUtc();

      final allIntervals = await _getAllIntervalsRateHistoryUsecase.execute(
        fromCurrency: currency,
        toCurrency: 'BTC',
        fromDate: fromDate,
        toDate: toDate,
      );

      emit(
        state.copyWith(
          allIntervalsData: allIntervals,
          hasFetchedAllIntervals: true,
        ),
      );
    } catch (e) {
      log.warning('[PriceChartBloc] _onFetchAllIntervals error: $e');
    }
  }

  DateTime _getFromDateForInterval(RateTimelineInterval interval) {
    final now = DateTime.now().toUtc();
    return switch (interval) {
      RateTimelineInterval.hour => now.subtract(const Duration(days: 1)),
      RateTimelineInterval.day => now.subtract(const Duration(days: 30)),
      RateTimelineInterval.week => now.subtract(const Duration(days: 54 * 7)),
    };
  }
}
