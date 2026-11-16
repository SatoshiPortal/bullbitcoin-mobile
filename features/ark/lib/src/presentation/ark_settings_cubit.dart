import 'package:bloc/bloc.dart';
import 'package:primitives/primitives.dart';

import '../domain/ark_failure.dart';
import '../domain/usecases/load_ark_settings_usecase.dart';
import '../domain/usecases/enable_ark_usecase.dart';
import '../domain/usecases/set_ark_enabled_usecase.dart';

sealed class ArkSettingsState {
  final ArkSettings? settings;
  final ArkFailure? failure;
  const ArkSettingsState({this.settings, this.failure});
  bool get busy => switch (this) {
    ArkSettingsLoading() || ArkSettingsUpdating() => true,
    ArkSettingsReady() || ArkSettingsFailed() => false,
  };
}

final class ArkSettingsLoading extends ArkSettingsState {
  const ArkSettingsLoading({super.settings});
}

final class ArkSettingsReady extends ArkSettingsState {
  const ArkSettingsReady(ArkSettings settings) : super(settings: settings);
}

final class ArkSettingsUpdating extends ArkSettingsState {
  const ArkSettingsUpdating(ArkSettings settings) : super(settings: settings);
}

final class ArkSettingsFailed extends ArkSettingsState {
  const ArkSettingsFailed(ArkFailure failure, {super.settings})
    : super(failure: failure);
}

final class ArkSettingsCubit extends Cubit<ArkSettingsState> {
  final LoadArkSettingsUsecase _load;
  final EnableArkUsecase _enable;
  final SetArkEnabledUsecase _setEnabled;
  int _readEpoch = 0;
  bool _mutating = false;
  ArkSettingsCubit(this._load, this._enable, this._setEnabled)
    : super(const ArkSettingsLoading());

  Future<void> load() async {
    if (isClosed || _mutating) return;
    final epoch = ++_readEpoch;
    emit(ArkSettingsLoading(settings: state.settings));
    final result = await _load.execute();
    if (isClosed || _mutating || epoch != _readEpoch) return;
    switch (result) {
      case Ok(:final value):
        emit(ArkSettingsReady(value));
      case Err(:final failure):
        emit(ArkSettingsFailed(failure));
    }
  }

  Future<void> enable({required bool privacyDisclosureAccepted}) => _update(
    true,
    (settings) async => (await _enable.execute(
      settings.config,
      privacyDisclosureAccepted: privacyDisclosureAccepted,
    )).map<void>((_) {}),
  );
  Future<void> disable() => _update(
    false,
    (settings) => _setEnabled.execute(settings.config.id, false),
  );

  Future<void> _update(
    bool enabled,
    Future<Result<void, ArkFailure>> Function(ArkSettings) action,
  ) async {
    final settings = state.settings;
    if (isClosed || _mutating || state.busy || settings == null) return;
    _mutating = true;
    ++_readEpoch;
    emit(ArkSettingsUpdating(settings));
    try {
      final result = await action(settings);
      if (isClosed) return;
      switch (result) {
        case Ok():
          emit(ArkSettingsReady(ArkSettings(settings.config, enabled)));
        // Creation may already have happened. Retain the original config;
        // any explicit retry uses the same idempotent provisioning path.
        case Err(:final failure):
          emit(ArkSettingsFailed(failure, settings: settings));
      }
    } finally {
      _mutating = false;
    }
  }
}
