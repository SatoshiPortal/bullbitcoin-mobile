import 'package:swaps/swaps.dart' show SwapServer;
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/swap/domain/entities/swap_route.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_swap_route_settings_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_swap_server_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/set_swap_exchange_fallback_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/set_swap_route_override_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/set_swap_server_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'swap_settings_cubit.freezed.dart';
part 'swap_settings_state.dart';

class SwapSettingsCubit extends Cubit<SwapSettingsState> {
  SwapSettingsCubit({
    required this._getSwapRouteSettingsUsecase,
    required this._setSwapExchangeFallbackUsecase,
    required this._setSwapRouteOverrideUsecase,
    required this._getSwapServerUsecase,
    required this._setSwapServerUsecase,
  }) : super(const SwapSettingsState());

  final GetSwapRouteSettingsUsecase _getSwapRouteSettingsUsecase;
  final SetSwapExchangeFallbackUsecase _setSwapExchangeFallbackUsecase;
  final SetSwapRouteOverrideUsecase _setSwapRouteOverrideUsecase;
  final GetSwapServerUsecase _getSwapServerUsecase;
  final SetSwapServerUsecase _setSwapServerUsecase;

  Future<void> load() async {
    final swapServer = await _getSwapServerUsecase.execute();
    if (isClosed) return;
    switch (swapServer) {
      case Ok(:final value):
        emit(
          state.copyWith(
            swapServer: value.server,
            swapServerEnvironment: value.environment,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
        return;
    }
    final routeSettings = await _getSwapRouteSettingsUsecase.execute();
    if (isClosed) return;
    switch (routeSettings) {
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
    final result = await _setSwapExchangeFallbackUsecase.execute(enabled);
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(state.copyWith(saving: false, exchangeFallbackEnabled: enabled));
      case Err(:final failure):
        emit(state.copyWith(saving: false, failure: failure));
    }
  }

  Future<void> setRouteOverride(SwapRouteOverride override) async {
    if (state.saving || !state.loaded) return;
    emit(state.copyWith(saving: true, failure: null));
    final result = await _setSwapRouteOverrideUsecase.execute(override);
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(state.copyWith(saving: false, routeOverride: override));
      case Err(:final failure):
        emit(state.copyWith(saving: false, failure: failure));
    }
  }

  /// Stores the server typed by the user. Returns the validation failure so
  /// the editor can show it next to the input; a storage failure is reported
  /// through the state like any other.
  Future<SwapValidationFailure?> setSwapServer(String input) async {
    if (state.saving) return null;
    emit(state.copyWith(saving: true, failure: null));
    final result = await _setSwapServerUsecase.execute(input);
    if (isClosed) return null;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(saving: false, swapServer: value));
        return null;
      case Err(failure: final SwapValidationFailure failure):
        emit(state.copyWith(saving: false));
        return failure;
      case Err(:final failure):
        emit(state.copyWith(saving: false, failure: failure));
        return null;
    }
  }
}
