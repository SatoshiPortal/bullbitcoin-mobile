part of 'price_chart_bloc.dart';

@freezed
class PriceChartEvent with _$PriceChartEvent {
  const factory PriceChartEvent.started({
    String? currency,
    RateTimelineInterval? interval,
  }) = PriceChartStarted;

  const factory PriceChartEvent.intervalChanged(RateTimelineInterval interval) =
      PriceChartIntervalChanged;

  const factory PriceChartEvent.dataPointSelected(int index) =
      PriceChartDataPointSelected;

  const factory PriceChartEvent.closed() = PriceChartClosed;

  const factory PriceChartEvent.fetchAllIntervals({required String currency}) =
      PriceChartFetchAllIntervals;
}
