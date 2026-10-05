import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_exchange_statistics_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/statistics_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

class StatisticsCubit extends Cubit<StatisticsState> {
  final GetExchangeStatisticsUsecase _getExchangeStatisticsUsecase;

  StatisticsCubit({required GetExchangeStatisticsUsecase getStatisticsUsecase})
    : _getExchangeStatisticsUsecase = getStatisticsUsecase,
      super(const StatisticsState());

  Future<void> loadStatistics() async {
    emit(state.copyWith(isLoading: true, failure: null));

    final result = await _getExchangeStatisticsUsecase.execute();
    if (isClosed) return;

    emit(switch (result) {
      Ok(:final value) => state.copyWith(isLoading: false, stats: value),
      Err(:final failure) => state.copyWith(isLoading: false, failure: failure),
    });
  }

  void clearError() {
    emit(state.copyWith(failure: null));
  }
}
