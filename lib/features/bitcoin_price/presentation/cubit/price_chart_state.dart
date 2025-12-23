part of 'price_chart_cubit.dart';

@freezed
sealed class PriceChartState with _$PriceChartState {
  const factory PriceChartState({
    @Default(false) bool isLoading,
    @Default([]) List<Rate> prices,
    String? currency,
    int? selectedDataPointIndex,
    Object? error,
    @Default(false) bool showChart,
  }) = _PriceChartState;

  const PriceChartState._();

  bool get hasPrices => prices.isNotEmpty;
  Rate? get selectedPrice {
    if (selectedDataPointIndex != null &&
        selectedDataPointIndex! >= 0 &&
        selectedDataPointIndex! < prices.length) {
      return prices[selectedDataPointIndex!];
    }
    return prices.isNotEmpty ? prices.last : null;
  }
}
