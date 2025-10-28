import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_all_drive_file_metadata_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_vault_from_drive_usecase.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull_google_drive/errors.dart';
import 'package:bb_mobile/features/recoverbull_google_drive/presentation/event.dart';
import 'package:bb_mobile/features/recoverbull_google_drive/presentation/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecoverBullGoogleDriveBloc
    extends Bloc<RecoverBullGoogleDriveEvent, RecoverBullGoogleDriveState> {
  final RecoverBullFlow flow;
  final FetchAllDriveFileMetadataUsecase _fetchAllDriveFileMetadataUsecase;
  final FetchVaultFromDriveUsecase _fetchDriveVaultUsecase;

  RecoverBullGoogleDriveBloc({
    required this.flow,
    required FetchAllDriveFileMetadataUsecase fetchAllDriveFileMetadataUsecase,
    required FetchVaultFromDriveUsecase fetchDriveBackupUsecase,
  }) : _fetchAllDriveFileMetadataUsecase = fetchAllDriveFileMetadataUsecase,
       _fetchDriveVaultUsecase = fetchDriveBackupUsecase,
       super(const RecoverBullGoogleDriveState()) {
    on<OnFetchDriveVaults>(_onFetchDriveVaults);
    on<OnSelectDriveFileMetadata>(_onSelectDriveFileMetadata);

    add(const OnFetchDriveVaults());
  }

  Future<void> _onFetchDriveVaults(
    OnFetchDriveVaults event,
    Emitter<RecoverBullGoogleDriveState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true));
      final backups = await _fetchAllDriveFileMetadataUsecase.execute();
      emit(state.copyWith(driveMetadata: backups));
    } catch (e) {
      emit(state.copyWith(error: FetchAllDriveFilesError()));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onSelectDriveFileMetadata(
    OnSelectDriveFileMetadata event,
    Emitter<RecoverBullGoogleDriveState> emit,
  ) async {
    try {
      emit(state.copyWith(error: null, selectedVault: null, isLoading: true));
      final vaultFile = await _fetchDriveVaultUsecase.execute(
        event.fileMetadata,
      );
      final vault = EncryptedVault(file: vaultFile);
      emit(state.copyWith(selectedVault: vault, isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: FetchAllDriveFilesError(), isLoading: false));
    }
  }
}
