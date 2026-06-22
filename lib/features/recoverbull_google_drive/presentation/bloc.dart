import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/delete_drive_file_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/export_drive_file_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_all_drive_file_metadata_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_vault_from_drive_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull_google_drive/domain/recoverbull_google_drive_failure.dart';
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
    required this._fetchAllDriveFileMetadataUsecase,
    required FetchVaultFromDriveUsecase fetchDriveBackupUsecase,
    required this._deleteDriveFileUsecase,
    required this._exportDriveFileUsecase,
  }) : _fetchDriveVaultUsecase = fetchDriveBackupUsecase,
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
      switch (await _fetchAllDriveFileMetadataUsecase.execute()) {
        case Ok(:final value):
          emit(state.copyWith(driveMetadata: value));
          log.fine('$OnFetchDriveVaults ${value.length} metadata found');
        case Err(:final failure):
          emit(
            state.copyWith(
              failure: RecoverBullGoogleDriveUnexpectedFailure(
                failure.logMessage,
              ),
            ),
          );
      }
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onSelectDriveFileMetadata(
    OnSelectDriveFileMetadata event,
    Emitter<RecoverBullGoogleDriveState> emit,
  ) async {
    try {
      emit(state.copyWith(failure: null, selectedVault: null, isLoading: true));
      switch (await _fetchDriveVaultUsecase.execute(event.fileMetadata)) {
        case Ok(:final value):
          emit(state.copyWith(selectedVault: value));
        case Err(:final failure):
          emit(
            state.copyWith(
              failure: RecoverBullGoogleDriveUnexpectedFailure(
                failure.logMessage,
              ),
            ),
          );
      }
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
      switch (await _deleteDriveFileUsecase.execute(event.fileMetadata.id)) {
        case Ok():
          final updatedMetadata = state.driveMetadata
              .where((file) => file.id != event.fileMetadata.id)
              .toList();
          emit(state.copyWith(driveMetadata: updatedMetadata));
          log.fine('$OnDeleteDriveFile succeed');
        case Err(:final failure):
          emit(
            state.copyWith(
              failure: RecoverBullGoogleDriveUnexpectedFailure(
                failure.logMessage,
              ),
            ),
          );
      }
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
      switch (await _exportDriveFileUsecase.execute(event.fileMetadata)) {
        case Ok():
          log.fine('$OnExportDriveFile succeed');
        case Err(:final failure):
          emit(
            state.copyWith(
              failure: RecoverBullGoogleDriveUnexpectedFailure(
                failure.logMessage,
              ),
            ),
          );
      }
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }
}
