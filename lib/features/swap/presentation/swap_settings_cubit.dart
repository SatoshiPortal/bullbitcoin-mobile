import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/domain/entities/swap_route.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_swap_route_settings_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/set_swap_exchange_fallback_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/set_swap_route_override_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'swap_settings_cubit.freezed.dart';
part 'swap_settings_state.dart';

class SwapSettingsCubit extends Cubit<SwapSettingsState> {
  SwapSettingsCubit({
    required this._getSwapRouteSettingsUsecase,
    required this._setSwapExchangeFallbackUsecase,
    required this._setSwapRouteOverrideUsecase,
  }) : super(const SwapSettingsState());

  final GetSwapRouteSettingsUsecase _getSwapRouteSettingsUsecase;
  final SetSwapExchangeFallbackUsecase _setSwapExchangeFallbackUsecase;
  final SetSwapRouteOverrideUsecase _setSwapRouteOverrideUsecase;

  Future<void> load() async {
    switch (await _getSwapRouteSettingsUsecase.execute()) {
      case Ok(:final value):
        emit(
          state.copyWith(
            loaded: true,
            exchangeFallbackEnabled: value.exchangeFallbackEnabled,
            routeOverride: value.override,
            devModeEnabled: value.devModeEnabled,
            failure: null,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
  }

  Future<void> setExchangeFallbackEnabled(bool enabled) async {
    if (state.saving || !state.loaded) return;
    emit(state.copyWith(saving: true, failure: null));
    switch (await _setSwapExchangeFallbackUsecase.execute(enabled)) {
      case Ok():
        emit(state.copyWith(saving: false, exchangeFallbackEnabled: enabled));
      case Err(:final failure):
        emit(state.copyWith(saving: false, failure: failure));
    }
  }

  Future<void> setRouteOverride(SwapRouteOverride override) async {
    if (state.saving || !state.loaded) return;
    emit(state.copyWith(saving: true, failure: null));
    switch (await _setSwapRouteOverrideUsecase.execute(override)) {
      case Ok():
        emit(state.copyWith(saving: false, routeOverride: override));
      case Err(:final failure):
        emit(state.copyWith(saving: false, failure: failure));
    }
  }
}
