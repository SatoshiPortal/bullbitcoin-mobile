part of 'price_chart_cubit.dart';

@freezed
sealed class PriceChartState with _$PriceChartState {
  const factory PriceChartState({
    @Default(false) bool isLoading,
    @Default([]) List<PricePoint> prices,
    String? currency,
    int? selectedDataPointIndex,
    BitcoinPriceFailure? failure,
    @Default(false) bool showChart,
  }) = _PriceChartState;

  const PriceChartState._();

  bool get hasPrices => prices.isNotEmpty;
  PricePoint? get selectedPrice {
    final index = selectedDataPointIndex;
    if (index != null && index >= 0 && index < prices.length) {
      return prices[index];
    }
    return prices.isNotEmpty ? prices.last : null;
  }
}
