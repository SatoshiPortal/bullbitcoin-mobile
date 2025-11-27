part of 'price_chart_bloc.dart';

@freezed
class PriceChartEvent with _$PriceChartEvent {
  const factory PriceChartEvent.started({String? currency}) = PriceChartStarted;

  const factory PriceChartEvent.dataPointSelected(int index) =
      PriceChartDataPointSelected;

  const factory PriceChartEvent.closed() = PriceChartClosed;

  const factory PriceChartEvent.refreshAllRates({required String currency}) =
      PriceChartRefreshAllRates;
}
