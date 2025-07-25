import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exchange_settings_cubit.freezed.dart';
part 'exchange_settings_state.dart';

class ExchangeSettingsCubit extends Cubit<ExchangeSettingsState> {
  ExchangeSettingsCubit({
    required GetExchangeUserSummaryUsecase getExchangeUserSummaryUsecase,
  }) : _getExchangeUserSummaryUsecase = getExchangeUserSummaryUsecase,
       super(const ExchangeSettingsState());

  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;

  Future<void> init() async {
    try {
      emit(state.copyWith(status: ExchangeSettingsStatus.loading));

      final userSummary = await _getExchangeUserSummaryUsecase.execute();
      emit(
        state.copyWith(
          status: ExchangeSettingsStatus.success,
          userSummary: userSummary,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ExchangeSettingsStatus.error,
          error: e.toString(),
        ),
      );
    }
  }
}
