import 'package:bb_mobile/features/app_startup/domain/usecases/init_wallets_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/fetch_usable_wallets_metadata_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_startup_bloc.freezed.dart';
part 'app_startup_event.dart';
part 'app_startup_state.dart';

class AppStartupBloc extends Bloc<AppStartupEvent, AppStartupState> {
  AppStartupBloc({
    required FetchUsableWalletsMetadataUseCase fetchAllWalletsMetadataUseCase,
    required InitWalletsUseCase initWalletsUseCase,
  })  : _fetchUsableWalletsMetadataUseCase = fetchAllWalletsMetadataUseCase,
        _initWalletsUseCase = initWalletsUseCase,
        super(const AppStartupState.initial()) {
    on<AppStartupStarted>(_onAppStartupStarted);
  }

  final FetchUsableWalletsMetadataUseCase _fetchUsableWalletsMetadataUseCase;
  final InitWalletsUseCase _initWalletsUseCase;

  Future<void> _onAppStartupStarted(
    AppStartupStarted event,
    Emitter<AppStartupState> emit,
  ) async {
    emit(const AppStartupState.loadingInProgress());
    try {
      final walletsMetadata =
          await _fetchUsableWalletsMetadataUseCase.execute();
      final hasExistingWallets = walletsMetadata.isNotEmpty;

      if (hasExistingWallets) {
        await _initWalletsUseCase.execute(walletsMetadata);
      }

      // Other startup logic can be added here instead of in `initState` of
      //  widgets

      emit(AppStartupState.success(hasExistingWallets: hasExistingWallets));
    } catch (e) {
      emit(
        AppStartupState.failure(e),
      );
    }
  }
}
