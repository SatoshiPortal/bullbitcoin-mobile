import 'dart:async';

import 'package:mempool/mempool.dart';
import 'package:bb_mobile/features/mempool_settings/domain/usecases/delete_custom_mempool_server_usecase.dart';
import 'package:bb_mobile/features/mempool_settings/domain/usecases/load_mempool_server_data_usecase.dart';
import 'package:bb_mobile/features/mempool_settings/domain/usecases/set_custom_mempool_server_usecase.dart';
import 'package:bb_mobile/features/mempool_settings/domain/usecases/check_mempool_server_status_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'mempool_settings_state.dart';
part 'mempool_settings_cubit.freezed.dart';

class MempoolSettingsCubit extends Cubit<MempoolSettingsState> {
  final LoadMempoolServerDataUsecase _loadDataUsecase;
  final SetCustomMempoolServerUsecase _setCustomServerUsecase;
  final DeleteCustomMempoolServerUsecase _deleteCustomServerUsecase;
  final CheckMempoolServerStatusUsecase _checkStatusUsecase;
  // Latest probe per row (custom or default); an older probe never writes.
  final _latestProbe = <bool, int>{};

  MempoolSettingsCubit({
    required this._loadDataUsecase,
    required this._setCustomServerUsecase,
    required this._deleteCustomServerUsecase,
    required this._checkStatusUsecase,
  }) : super(const MempoolSettingsState());

  Future<void> loadData({bool? isLiquid}) async {
    emit(
      state.copyWith(
        isLiquid: isLiquid ?? state.isLiquid,
        isLoading: true,
        failure: null,
      ),
    );
    try {
      await _fetchAndApplyData();
    } finally {
      emit(state.copyWith(isLoading: false));
    }
    // Probe the listed servers so the screen shows a real status on open, as
    // the Electrum settings do. Not awaited: callers (and a save) only wait
    // for the list, and a late answer is dropped if the list moved on.
    final defaultServer = state.defaultServer;
    final customServer = state.customServer;
    unawaited(
      Future.wait([
        if (defaultServer != null) checkServerStatus(defaultServer),
        if (customServer != null) checkServerStatus(customServer),
      ]),
    );
  }

  /// Reload server data from local DB then probe each server's status, all
  /// under a single `isLoading` flag so the top progress bar reflects the
  /// full pull-to-refresh duration.
  Future<void> refresh() async {
    emit(state.copyWith(isLoading: true));
    try {
      await _fetchAndApplyData();
      final defaultServer = state.defaultServer;
      final customServer = state.customServer;
      await Future.wait([
        if (defaultServer != null) checkServerStatus(defaultServer),
        if (customServer != null) checkServerStatus(customServer),
      ]);
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _fetchAndApplyData() async {
    final request = LoadMempoolServerDataRequest(isLiquid: state.isLiquid);
    switch (await _loadDataUsecase.execute(request)) {
      case Ok(:final value):
        emit(
          state.copyWith(
            defaultServer: value.defaultServer,
            customServer: value.customServer,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
  }

  Future<bool> setCustomServer(String url, {bool enableSsl = true}) async {
    emit(state.copyWith(isSavingServer: true, failure: null));

    final request = SetCustomMempoolServerRequest(
      url: url,
      isLiquid: state.isLiquid,
      enableSsl: enableSsl,
    );

    switch (await _setCustomServerUsecase.execute(request)) {
      case Ok():
        await loadData();
        emit(state.copyWith(isSavingServer: false));
        return true;
      case Err(:final failure):
        emit(state.copyWith(isSavingServer: false, failure: failure));
        return false;
    }
  }

  Future<void> deleteCustomServer() async {
    emit(state.copyWith(isDeletingServer: true, failure: null));

    final request = DeleteCustomMempoolServerRequest(isLiquid: state.isLiquid);
    switch (await _deleteCustomServerUsecase.execute(request)) {
      case Ok():
        emit(state.copyWith(customServer: null, isDeletingServer: false));
      case Err(:final failure):
        emit(state.copyWith(isDeletingServer: false, failure: failure));
    }
  }

  Future<void> checkServerStatus(MempoolServerDto server) async {
    if (server.status.isChecking) {
      return;
    }
    final probe = (_latestProbe[server.isCustom] ?? 0) + 1;
    _latestProbe[server.isCustom] = probe;

    final updatedServer = server.copyWith(status: MempoolServerStatus.checking);

    if (server.isCustom) {
      emit(state.copyWith(customServer: updatedServer));
    } else {
      emit(state.copyWith(defaultServer: updatedServer));
    }

    // A validation Err here just means the server is offline — not a
    // user-facing error, so it's never surfaced as a failure.
    final isValid = await _checkStatusUsecase.execute(server);
    // The screen may have closed, started a newer probe, switched network or
    // deleted this server while the probe ran; never write a stale answer.
    if (isClosed || _latestProbe[server.isCustom] != probe) return;
    if (!_shows(server)) return;

    final finalServer = server.copyWith(
      status: isValid
          ? MempoolServerStatus.online
          : MempoolServerStatus.offline,
    );
    if (server.isCustom) {
      emit(state.copyWith(customServer: finalServer));
    } else {
      emit(state.copyWith(defaultServer: finalServer));
    }
  }

  bool _shows(MempoolServerDto server) {
    final shown = server.isCustom ? state.customServer : state.defaultServer;
    return shown != null &&
        shown.url == server.url &&
        shown.isLiquid == server.isLiquid &&
        shown.isTestnet == server.isTestnet;
  }

  void clearError() {
    emit(state.copyWith(failure: null));
  }
}
