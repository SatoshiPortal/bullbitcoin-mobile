import 'package:bb_mobile/core/exchange/domain/usecases/get_order_stats_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/statistics_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class StatisticsCubit extends Cubit<StatisticsState> {
  final GetOrderStatsUsecase _getOrderStatsUsecase;

  StatisticsCubit({
    required GetOrderStatsUsecase getOrderStatsUsecase,
  })  : _getOrderStatsUsecase = getOrderStatsUsecase,
        super(const StatisticsState());

  Future<void> loadStats() async {
    if (state.isLoading) return;

    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      final stats = await _getOrderStatsUsecase.execute();
      emit(state.copyWith(
        isLoading: false,
        orderStats: stats,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> refresh() async {
    emit(state.copyWith(errorMessage: null));
    await loadStats();
  }
}






