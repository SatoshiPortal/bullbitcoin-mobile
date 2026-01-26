import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/delete_drive_file_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/export_drive_file_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_all_drive_file_metadata_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_vault_from_drive_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
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
  final DeleteDriveFileUsecase _deleteDriveFileUsecase;
  final ExportDriveFileUsecase _exportDriveFileUsecase;

  RecoverBullGoogleDriveBloc({
    required this.flow,
    required FetchAllDriveFileMetadataUsecase fetchAllDriveFileMetadataUsecase,
    required FetchVaultFromDriveUsecase fetchDriveBackupUsecase,
    required DeleteDriveFileUsecase deleteDriveFileUsecase,
    required ExportDriveFileUsecase exportDriveFileUsecase,
  }) : _fetchAllDriveFileMetadataUsecase = fetchAllDriveFileMetadataUsecase,
       _fetchDriveVaultUsecase = fetchDriveBackupUsecase,
       _deleteDriveFileUsecase = deleteDriveFileUsecase,
       _exportDriveFileUsecase = exportDriveFileUsecase,
       super(const RecoverBullGoogleDriveState()) {
    on<OnFetchDriveVaults>(_onFetchDriveVaults);
    on<OnSelectDriveFileMetadata>(_onSelectDriveFileMetadata);
    on<OnDeleteDriveFile>(_onDeleteDriveFile);
    on<OnExportDriveFile>(_onExportDriveFile);

    add(const OnFetchDriveVaults());
  }

  Future<void> _onFetchDriveVaults(
    OnFetchDriveVaults event,
    Emitter<RecoverBullGoogleDriveState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true));
      final driveMetadata = await _fetchAllDriveFileMetadataUsecase.execute();
      emit(state.copyWith(driveMetadata: driveMetadata));
      log.fine('$OnFetchDriveVaults ${driveMetadata.length} metadata found');
    } catch (e) {
      log.severe('$OnFetchDriveVaults: $e', trace: StackTrace.current);
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

      final vault = await _fetchDriveVaultUsecase.execute(event.fileMetadata);
      emit(state.copyWith(selectedVault: vault));
    } catch (e) {
      log.severe('$OnSelectDriveFileMetadata: $e', trace: StackTrace.current);
      emit(state.copyWith(error: FetchAllDriveFilesError()));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onDeleteDriveFile(
    OnDeleteDriveFile event,
    Emitter<RecoverBullGoogleDriveState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true));
      await _deleteDriveFileUsecase.execute(event.fileMetadata.id);
      final updatedMetadata =
          state.driveMetadata
              .where((file) => file.id != event.fileMetadata.id)
              .toList();
      emit(state.copyWith(driveMetadata: updatedMetadata));
      log.fine('$OnDeleteDriveFile succeed');
    } catch (e) {
      log.severe('$OnDeleteDriveFile: $e', trace: StackTrace.current);
      emit(state.copyWith(error: FetchAllDriveFilesError()));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onExportDriveFile(
    OnExportDriveFile event,
    Emitter<RecoverBullGoogleDriveState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true));
      await _exportDriveFileUsecase.execute(event.fileMetadata);
      log.fine('$OnExportDriveFile succeed');
    } catch (e) {
      log.severe('$OnExportDriveFile: $e', trace: StackTrace.current);
      emit(state.copyWith(error: FetchAllDriveFilesError()));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }
}
