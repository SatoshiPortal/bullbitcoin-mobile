part of 'price_chart_bloc.dart';

@freezed
sealed class PriceChartState with _$PriceChartState {
  const factory PriceChartState({
    @Default(null) String? currency,
    @Default(null) RateTimelineInterval? selectedInterval,
    @Default(null) RateHistory? rateHistory,
    @Default(null) Map<String, RateHistory>? allIntervalsData,
    @Default(null) int? selectedDataPointIndex,
    @Default(false) bool isLoading,
    @Default(null) Object? error,
    @Default(false) bool hasFetchedAllIntervals,
  }) = _PriceChartState;
}
