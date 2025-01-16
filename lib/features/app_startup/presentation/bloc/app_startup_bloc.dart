import 'package:bb_mobile/features/wallet/domain/usecases/fetch_all_wallets_metadata_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/init_wallets_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_startup_event.dart';
part 'app_startup_state.dart';
part 'app_startup_bloc.freezed.dart';

class AppStartupBloc extends Bloc<AppStartupEvent, AppStartupState> {
  AppStartupBloc({
    required FetchAllWalletsMetadataUseCase fetchAllWalletsMetadataUseCase,
    required InitWalletsUseCase initWalletsUseCase,
  })  : _fetchAllWalletsMetadataUseCase = fetchAllWalletsMetadataUseCase,
        _initWalletsUseCase = initWalletsUseCase,
        super(const AppStartupState.initial()) {
    on<AppStartupStarted>(_onAppStartupStarted);
  }

  final FetchAllWalletsMetadataUseCase _fetchAllWalletsMetadataUseCase;
  final InitWalletsUseCase _initWalletsUseCase;

  Future<void> _onAppStartupStarted(
    AppStartupStarted event,
    Emitter<AppStartupState> emit,
  ) async {
    emit(const AppStartupState.loadingInProgress());
    try {
      final walletsMetadata = await _fetchAllWalletsMetadataUseCase.execute();
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
