import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exchange_settings_cubit.freezed.dart';
part 'exchange_settings_state.dart';

class ExchangeSettingsCubit extends Cubit<ExchangeSettingsState> {
  ExchangeSettingsCubit() : super(const ExchangeSettingsState());

  Future<void> init() async {
    try {
      emit(state.copyWith(status: ExchangeSettingsStatus.loading));

      // TODO: Add initialization logic here

      emit(state.copyWith(status: ExchangeSettingsStatus.success));
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
