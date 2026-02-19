import 'package:bb_mobile/core/exchange/domain/usecases/get_order_stats_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/statistics_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class StatisticsCubit extends Cubit<StatisticsState> {
  StatisticsCubit({required GetOrderStatsUsecase getOrderStatsUsecase})
    : _getOrderStatsUsecase = getOrderStatsUsecase,
      super(const StatisticsState());

  final GetOrderStatsUsecase _getOrderStatsUsecase;

  Future<void> loadStatistics() async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      final stats = await _getOrderStatsUsecase.execute();

      emit(state.copyWith(isLoading: false, stats: stats));
    } catch (e) {
      log.severe(
        message: 'Failed to load statistics',
        error: e,
        trace: StackTrace.current,
      );
      emit(
        state.copyWith(isLoading: false, error: 'Failed to load statistics'),
      );
    }
  }

  void clearError() {
    emit(state.copyWith(error: null));
  }
}
