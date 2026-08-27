import 'package:bb_mobile/core/mempool/application/dtos/mempool_server_dto.dart';
import 'package:bb_mobile/core/mempool/application/dtos/mempool_settings_dto.dart';
import 'package:bb_mobile/core/mempool/application/dtos/requests/delete_custom_mempool_server_request.dart';
import 'package:bb_mobile/core/mempool/application/dtos/requests/load_mempool_server_data_request.dart';
import 'package:bb_mobile/core/mempool/application/dtos/requests/set_custom_mempool_server_request.dart';
import 'package:bb_mobile/core/mempool/application/dtos/requests/update_mempool_settings_request.dart';
import 'package:bb_mobile/core/mempool/application/usecases/delete_custom_mempool_server_usecase.dart';
import 'package:bb_mobile/core/mempool/application/usecases/load_mempool_server_data_usecase.dart';
import 'package:bb_mobile/core/mempool/application/usecases/set_custom_mempool_server_usecase.dart';
import 'package:bb_mobile/core/mempool/application/usecases/update_mempool_settings_usecase.dart';
import 'package:bb_mobile/core/mempool/domain/errors/mempool_failure.dart';
import 'package:bb_mobile/core/mempool/domain/ports/mempool_server_validator_port.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_status.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'mempool_settings_state.dart';
part 'mempool_settings_cubit.freezed.dart';

class MempoolSettingsCubit extends Cubit<MempoolSettingsState> {
  final LoadMempoolServerDataUsecase _loadDataUsecase;
  final SetCustomMempoolServerUsecase _setCustomServerUsecase;
  final DeleteCustomMempoolServerUsecase _deleteCustomServerUsecase;
  final UpdateMempoolSettingsUsecase _updateSettingsUsecase;
  final MempoolServerValidatorPort _validator;

  MempoolSettingsCubit({
    required this._loadDataUsecase,
    required this._setCustomServerUsecase,
    required this._deleteCustomServerUsecase,
    required this._updateSettingsUsecase,
    required this._validator,
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
            settings: value.settings,
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

  Future<void> updateUseForFeeEstimation(bool value) async {
    emit(state.copyWith(isUpdatingSettings: true, failure: null));

    final request = UpdateMempoolSettingsRequest(
      isLiquid: state.isLiquid,
      useForFeeEstimation: value,
    );

    switch (await _updateSettingsUsecase.execute(request)) {
      case Ok():
        final updatedSettings = state.settings != null
            ? MempoolSettingsDto(
                network: state.settings!.network,
                useForFeeEstimation: value,
              )
            : null;
        emit(
          state.copyWith(settings: updatedSettings, isUpdatingSettings: false),
        );
      case Err(:final failure):
        emit(state.copyWith(isUpdatingSettings: false, failure: failure));
    }
  }

  Future<void> checkServerStatus(MempoolServerDto server) async {
    if (server.status.isChecking) {
      return;
    }

    final network = MempoolServerNetwork.fromEnvironment(
      isTestnet: server.isTestnet,
      isLiquid: server.isLiquid,
    );

    final updatedServer = server.copyWith(status: MempoolServerStatus.checking);

    if (server.isCustom) {
      emit(state.copyWith(customServer: updatedServer));
    } else {
      emit(state.copyWith(defaultServer: updatedServer));
    }

    // A validation Err here just means the server is offline — not a
    // user-facing error, so it's never surfaced as a failure.
    final isValid = (await _validator.validateServer(
      url: server.url,
      network: network,
      enableSsl: server.enableSsl,
    )).fold((_) => true, (_) => false);

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

  void clearError() {
    emit(state.copyWith(failure: null));
  }
}
