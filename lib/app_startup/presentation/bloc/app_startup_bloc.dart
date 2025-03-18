import 'package:bb_mobile/app_startup/domain/usecases/check_for_existing_default_wallets_usecase.dart';
import 'package:bb_mobile/app_startup/domain/usecases/init_wallets_usecase.dart';
import 'package:bb_mobile/app_startup/domain/usecases/initialize_tor_usecase.dart';
import 'package:bb_mobile/app_startup/domain/usecases/reset_app_data_usecase.dart';
import 'package:bb_mobile/app_unlock/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_startup_bloc.freezed.dart';
part 'app_startup_event.dart';
part 'app_startup_state.dart';

class AppStartupBloc extends Bloc<AppStartupEvent, AppStartupState> {
  final InitializeTorUseCase _initializeTorUseCase;

  AppStartupBloc({
    required ResetAppDataUseCase resetAppDataUseCase,
    required CheckPinCodeExistsUseCase checkPinCodeExistsUseCase,
    required CheckForExistingDefaultWalletsUseCase
        checkForExistingDefaultWalletsUseCase,
    required InitExistingWalletsUseCase initExistingWalletsUseCase,
    required InitializeTorUseCase initializeTorUseCase,
  })  : _resetAppDataUseCase = resetAppDataUseCase,
        _checkPinCodeExistsUseCase = checkPinCodeExistsUseCase,
        _checkForExistingDefaultWalletsUseCase =
            checkForExistingDefaultWalletsUseCase,
        _initExistingWalletsUseCase = initExistingWalletsUseCase,
        _initializeTorUseCase = initializeTorUseCase,
        super(const AppStartupState.initial()) {
    on<AppStartupStarted>(_onAppStartupStarted);
  }

  final ResetAppDataUsecase _resetAppDataUsecase;
  final CheckPinCodeExistsUsecase _checkPinCodeExistsUsecase;
  final CheckForExistingDefaultWalletsUsecase
      _checkForExistingDefaultWalletsUsecase;

  final InitExistingWalletsUsecase _initExistingWalletsUsecase;

  Future<void> _onAppStartupStarted(
    AppStartupStarted event,
    Emitter<AppStartupState> emit,
  ) async {
    emit(const AppStartupState.loadingInProgress());
    try {
      await _initializeTorUseCase.execute();

      final doDefaultWalletsExist =
          await _checkForExistingDefaultWalletsUsecase.execute();
      bool isPinCodeSet = false;

      if (doDefaultWalletsExist) {
        await _initExistingWalletsUsecase.execute();
        isPinCodeSet = await _checkPinCodeExistsUsecase.execute();
        // Other startup logic can be added here, e.g. payjoin sessions resume
      } else {
        // This is a fresh install, so reset the app data that might still be
        //  there from a previous install.
        //  (e.g. secure storage data on iOS like the pin code)
        await _resetAppDataUseCase.execute();

        // TODO: StartTorUseCase.execute()
      }

      emit(
        AppStartupState.success(
          isPinCodeSet: isPinCodeSet,
          hasDefaultWallets: doDefaultWalletsExist,
        ),
      );
    } catch (e) {
      emit(
        AppStartupState.failure(e),
      );
    }
  }
}
