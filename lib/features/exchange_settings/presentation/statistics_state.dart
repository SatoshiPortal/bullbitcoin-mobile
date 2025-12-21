import 'package:bb_mobile/core/exchange/domain/entity/order_stats.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'statistics_state.freezed.dart';

@freezed
sealed class StatisticsState with _$StatisticsState {
  const StatisticsState._();

  const factory StatisticsState({
    @Default(false) bool isLoading,
    OrderStats? orderStats,
    String? errorMessage,
  }) = _StatisticsState;

  bool get hasError => errorMessage != null;
  bool get hasStats => orderStats != null;
}

