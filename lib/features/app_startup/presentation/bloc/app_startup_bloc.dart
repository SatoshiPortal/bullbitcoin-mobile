import 'package:bb_mobile/features/app_startup/domain/usecases/get_wallets_metadata_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/init_wallets_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/reset_app_data_usecase.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_startup_bloc.freezed.dart';
part 'app_startup_event.dart';
part 'app_startup_state.dart';

class AppStartupBloc extends Bloc<AppStartupEvent, AppStartupState> {
  AppStartupBloc({
    required ResetAppDataUsecase resetAppDataUsecase,
    required CheckPinCodeExistsUsecase checkPinCodeExistsUsecase,
    required GetWalletsMetadataUseCase getWalletsMetadataUseCase,
    required InitWalletsUseCase initWalletsUseCase,
  })  : _resetAppDataUsecase = resetAppDataUsecase,
        _checkPinCodeExistsUsecase = checkPinCodeExistsUsecase,
        _getWalletsMetadataUseCase = getWalletsMetadataUseCase,
        _initWalletsUseCase = initWalletsUseCase,
        super(const AppStartupState.initial()) {
    on<AppStartupStarted>(_onAppStartupStarted);
  }

  final ResetAppDataUsecase _resetAppDataUsecase;
  final CheckPinCodeExistsUsecase _checkPinCodeExistsUsecase;
  final GetWalletsMetadataUseCase _getWalletsMetadataUseCase;
  final InitWalletsUseCase _initWalletsUseCase;

  Future<void> _onAppStartupStarted(
    AppStartupStarted event,
    Emitter<AppStartupState> emit,
  ) async {
    emit(const AppStartupState.loadingInProgress());
    try {
      final walletsMetadata = await _getWalletsMetadataUseCase.execute();
      final hasExistingWallets = walletsMetadata.isNotEmpty;
      bool isPinCodeSet = false;

      if (hasExistingWallets) {
        await _initWalletsUseCase.execute(walletsMetadata);
        isPinCodeSet = await _checkPinCodeExistsUsecase.execute();
        // Other startup logic can be added here, e.g. payjoin sessions resume
      } else {
        // This is a fresh install, so reset the app data that might still be
        //  there from a previous install.
        //  (e.g. secure storage data on iOS like the pin code)
        await _resetAppDataUsecase.execute();
      }

      emit(
        AppStartupState.success(
          hasExistingWallets: hasExistingWallets,
          isPinCodeSet: isPinCodeSet,
        ),
      );
    } catch (e) {
      emit(
        AppStartupState.failure(e),
      );
    }
  }
}
