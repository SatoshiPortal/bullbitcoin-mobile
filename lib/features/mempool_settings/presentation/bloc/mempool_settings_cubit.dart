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
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'mempool_settings_state.dart';
part 'mempool_settings_cubit.freezed.dart';

class MempoolSettingsCubit extends Cubit<MempoolSettingsState> {
  final LoadMempoolServerDataUsecase _loadDataUsecase;
  final SetCustomMempoolServerUsecase _setCustomServerUsecase;
  final DeleteCustomMempoolServerUsecase _deleteCustomServerUsecase;
  final UpdateMempoolSettingsUsecase _updateSettingsUsecase;

  MempoolSettingsCubit({
    required LoadMempoolServerDataUsecase loadDataUsecase,
    required SetCustomMempoolServerUsecase setCustomServerUsecase,
    required DeleteCustomMempoolServerUsecase deleteCustomServerUsecase,
    required UpdateMempoolSettingsUsecase updateSettingsUsecase,
  }) : _loadDataUsecase = loadDataUsecase,
       _setCustomServerUsecase = setCustomServerUsecase,
       _deleteCustomServerUsecase = deleteCustomServerUsecase,
       _updateSettingsUsecase = updateSettingsUsecase,
       super(const MempoolSettingsState());

  Future<void> loadData({bool? isLiquid}) async {
    emit(
      state.copyWith(
        isLiquid: isLiquid ?? state.isLiquid,
        isLoading: true,
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
          errorMessage: 'Failed to load mempool server data: ${e.toString()}',
        ),
      );
    }
  }

  Future<bool> setCustomServer(String url) async {
    emit(state.copyWith(isSavingServer: true, errorMessage: null));

    try {
      final request = SetCustomMempoolServerRequest(
        url: url,
        isLiquid: state.isLiquid,
      );

      final result = await _setCustomServerUsecase.execute(request);

      if (result.isValid) {
        // Reload data to get the updated server
        await loadData();
        return true;
      } else {
        emit(
          state.copyWith(
            isSavingServer: false,
            errorMessage: result.errorMessage,
          ),
        );
        return false;
      }
    } catch (e) {
      emit(
        state.copyWith(
          isSavingServer: false,
          errorMessage: 'Failed to save custom server: ${e.toString()}',
        ),
      );
      return false;
    }
  }

  Future<void> deleteCustomServer() async {
    emit(state.copyWith(isDeletingServer: true, errorMessage: null));

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
          errorMessage: 'Failed to delete custom server: ${e.toString()}',
        ),
      );
    }
  }

  Future<void> updateUseForFeeEstimation(bool value) async {
    emit(state.copyWith(isUpdatingSettings: true, errorMessage: null));

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
          errorMessage: 'Failed to update settings: ${e.toString()}',
        ),
      );
    }
  }

  void clearError() {
    emit(state.copyWith(errorMessage: null));
  }
}
