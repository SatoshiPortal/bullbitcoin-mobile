import 'package:bull_swap/bull_swap.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:primitives/primitives.dart';

part 'swap_provider_settings_state.dart';
part 'swap_provider_settings_cubit.freezed.dart';

class SwapProviderSettingsCubit extends Cubit<SwapProviderSettingsState> {
  final SwapProviderStore _store;
  final SwitchSwapProvider _switch;

  SwapProviderSettingsCubit(this._store, this._switch)
    : super(const SwapProviderSettingsState());

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, failure: null, switchBlocked: false));
    try {
      final providers = await _store.all();
      final active = await _store.active();
      emit(state.copyWith(providers: providers, activeId: active?.id));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> select(String providerId) async {
    emit(
      state.copyWith(isSwitching: true, failure: null, switchBlocked: false),
    );
    switch (await _switch.call(providerId)) {
      case Ok(:final value):
        emit(state.copyWith(isSwitching: false, activeId: value.id));
      case Err(:final failure):
        emit(
          state.copyWith(
            isSwitching: false,
            failure: failure,
            switchBlocked: failure is SwapSwitchBlockedFailure,
          ),
        );
    }
  }

  Future<bool> addCustomBoltz({
    required String name,
    required String url,
  }) async {
    final normalized = _normalizeUrl(url);
    if (normalized == null) {
      emit(
        state.copyWith(
          failure: const SwapProviderMisconfiguredFailure('Invalid URL'),
        ),
      );
      return false;
    }
    emit(state.copyWith(isSaving: true, failure: null));
    try {
      await _store.addCustomBoltz(
        name: name.trim().isEmpty ? normalized : name.trim(),
        baseUrl: normalized,
      );
      await load();
      return true;
    } catch (error) {
      emit(
        state.copyWith(
          isSaving: false,
          failure: SwapProviderMisconfiguredFailure(error.toString()),
        ),
      );
      return false;
    } finally {
      if (!isClosed) emit(state.copyWith(isSaving: false));
    }
  }

  Future<void> deleteCustom(String providerId) async {
    emit(state.copyWith(isDeleting: true, failure: null));
    try {
      await _store.removeCustom(providerId);
      await load();
    } finally {
      emit(state.copyWith(isDeleting: false));
    }
  }

  void clearError() =>
      emit(state.copyWith(failure: null, switchBlocked: false));

  String? _normalizeUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;
    value = value.replaceFirst(RegExp(r'^https?://'), '');
    value = value.replaceFirst(RegExp(r'/+$'), '');
    if (value.isEmpty || value.contains(' ')) return null;
    if (!value.contains('.')) return null;
    return value;
  }
}
