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
import 'package:bb_mobile/core/mempool/domain/errors/mempool_server_exception.dart';
import 'package:bb_mobile/core/mempool/domain/ports/mempool_server_validator_port.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_status.dart';
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
    required LoadMempoolServerDataUsecase loadDataUsecase,
    required SetCustomMempoolServerUsecase setCustomServerUsecase,
    required DeleteCustomMempoolServerUsecase deleteCustomServerUsecase,
    required UpdateMempoolSettingsUsecase updateSettingsUsecase,
    required MempoolServerValidatorPort validator,
  }) : _loadDataUsecase = loadDataUsecase,
       _setCustomServerUsecase = setCustomServerUsecase,
       _deleteCustomServerUsecase = deleteCustomServerUsecase,
       _updateSettingsUsecase = updateSettingsUsecase,
       _validator = validator,
       super(const MempoolSettingsState());

  Future<void> loadData({bool? isLiquid}) async {
    emit(
      state.copyWith(
        isLiquid: isLiquid ?? state.isLiquid,
        isLoading: true,
        setServerError: null,
        errorMessage: null,
      ),
    );

    try {
      final request = LoadMempoolServerDataRequest(isLiquid: state.isLiquid);

      final response = await _loadDataUsecase.execute(request);

      emit(
        state.copyWith(
          defaultServer: response.defaultServer,
          customServer: response.customServer,
          settings: response.settings,
          isLoading: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<bool> setCustomServer(String url, {bool enableSsl = true}) async {
    emit(state.copyWith(
      isSavingServer: true,
      setServerError: null,
      validationErrorType: null,
      errorMessage: null,
    ));

    try {
      final request = SetCustomMempoolServerRequest(
        url: url,
        isLiquid: state.isLiquid,
        enableSsl: enableSsl,
      );

      final result = await _setCustomServerUsecase.execute(request);

      if (result.isValid) {
        await loadData();
        emit(state.copyWith(isSavingServer: false));
        return true;
      } else {
        emit(
          state.copyWith(
            isSavingServer: false,
            setServerError: result.errorType,
            validationErrorType: result.validationErrorType,
          ),
        );
        return false;
      }
    } catch (e) {
      emit(
        state.copyWith(
          isSavingServer: false,
          errorMessage: e.toString(),
        ),
      );
      return false;
    }
  }

  Future<void> deleteCustomServer() async {
    emit(state.copyWith(isDeletingServer: true, setServerError: null, errorMessage: null));

    try {
      final request = DeleteCustomMempoolServerRequest(
        isLiquid: state.isLiquid,
      );

      await _deleteCustomServerUsecase.execute(request);

      emit(state.copyWith(customServer: null, isDeletingServer: false));
    } catch (e) {
      emit(
        state.copyWith(
          isDeletingServer: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> updateUseForFeeEstimation(bool value) async {
    emit(state.copyWith(isUpdatingSettings: true, setServerError: null, errorMessage: null));

    try {
      final request = UpdateMempoolSettingsRequest(
        isLiquid: state.isLiquid,
        useForFeeEstimation: value,
      );

      await _updateSettingsUsecase.execute(request);

      final updatedSettings = state.settings != null
          ? MempoolSettingsDto(
              network: state.settings!.network,
              useForFeeEstimation: value,
            )
          : null;

      emit(
        state.copyWith(settings: updatedSettings, isUpdatingSettings: false),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isUpdatingSettings: false,
          errorMessage: e.toString(),
        ),
      );
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

    try {
      final isValid = await _validator.validateServer(
        url: server.url,
        network: network,
        enableSsl: server.enableSsl,
      );

      final finalStatus =
          isValid ? MempoolServerStatus.online : MempoolServerStatus.offline;
      final finalServer = server.copyWith(status: finalStatus);

      if (server.isCustom) {
        emit(state.copyWith(customServer: finalServer));
      } else {
        emit(state.copyWith(defaultServer: finalServer));
      }
    } catch (e) {
      final finalServer = server.copyWith(status: MempoolServerStatus.offline);
      if (server.isCustom) {
        emit(state.copyWith(customServer: finalServer));
      } else {
        emit(state.copyWith(defaultServer: finalServer));
      }
    }
  }

  void clearError() {
    emit(state.copyWith(
      setServerError: null,
      validationErrorType: null,
      errorMessage: null,
    ));
  }
}
