part of 'price_chart_bloc.dart';

@freezed
sealed class PriceChartState with _$PriceChartState {
  const factory PriceChartState({
    @Default(null) String? currency,
    @Default(null) CompositeRateHistory? compositeRateHistory,
    @Default(null) int? selectedDataPointIndex,
    @Default(false) bool isLoading,
    @Default(null) Object? error,
  }) = _PriceChartState;
}
