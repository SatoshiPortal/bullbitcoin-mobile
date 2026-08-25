import 'dart:async';

import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class EmbeddedTorStatusState {
  final bool configurationLoaded;
  final bool visible;
  final bool externalProxySelected;
  final TorConnectionState connection;

  const EmbeddedTorStatusState({
    this.configurationLoaded = false,
    this.visible = false,
    this.externalProxySelected = false,
    this.connection = const TorUninitialized(),
  });

  EmbeddedTorStatusState copyWith({
    bool? configurationLoaded,
    bool? visible,
    bool? externalProxySelected,
    TorConnectionState? connection,
  }) {
    return EmbeddedTorStatusState(
      configurationLoaded: configurationLoaded ?? this.configurationLoaded,
      visible: visible ?? this.visible,
      externalProxySelected:
          externalProxySelected ?? this.externalProxySelected,
      connection: connection ?? this.connection,
    );
  }
}

class EmbeddedTorStatusCubit extends Cubit<EmbeddedTorStatusState> {
  final GetSettingsUsecase _getSettingsUsecase;
  final WatchTorConnectionUsecase _watchTorConnectionUsecase;
  final RetryTorConnectionUsecase _retryTorConnectionUsecase;
  StreamSubscription<TorConnectionState>? _connectionSubscription;
  int _configurationGeneration = 0;
  Future<bool> Function()? _shouldShow;

  EmbeddedTorStatusCubit({
    required this._getSettingsUsecase,
    required this._watchTorConnectionUsecase,
    required this._retryTorConnectionUsecase,
  }) : super(const EmbeddedTorStatusState());

  void setVisibilityChecker(Future<bool> Function() shouldShow) {
    _shouldShow = shouldShow;
  }

  Future<void> init() async {
    await _connectionSubscription?.cancel();
    _connectionSubscription = _watchTorConnectionUsecase.execute().listen((
      connection,
    ) {
      if (!isClosed) emit(state.copyWith(connection: connection));
    });
    await refreshConfiguration();
  }

  Future<void> refreshConfiguration() async {
    final generation = ++_configurationGeneration;
    try {
      final settings = await _getSettingsUsecase.execute();
      final visible = await _shouldShow?.call() ?? false;
      if (isClosed || generation != _configurationGeneration) return;
      if (state.configurationLoaded &&
          state.externalProxySelected == settings.useTorProxy &&
          state.visible == visible) {
        return;
      }
      emit(
        state.copyWith(
          configurationLoaded: true,
          visible: visible,
          externalProxySelected: settings.useTorProxy,
        ),
      );
    } catch (_) {
      // Keep the indicator hidden until its routing mode can be established.
    }
  }

  Future<void> retry() async {
    await _retryTorConnectionUsecase.execute();
  }

  @override
  Future<void> close() async {
    await _connectionSubscription?.cancel();
    return super.close();
  }
}
