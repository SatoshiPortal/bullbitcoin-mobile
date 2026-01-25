import 'package:bb_mobile/core/exchange/domain/entity/order_stats.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'statistics_state.freezed.dart';

@freezed
abstract class StatisticsState with _$StatisticsState {
  const factory StatisticsState({
    OrderStatsResponse? stats,
    @Default(false) bool isLoading,
    String? error,
  }) = _StatisticsState;

  const StatisticsState._();

  bool get hasStats => stats != null;

  OrderStats? get orderStats => stats?.orderStats;
  BillerStats? get billerStats => stats?.billerStats;
  DateTime? get asOf => stats?.asOf;
}
