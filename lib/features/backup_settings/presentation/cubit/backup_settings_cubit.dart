import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/backup_wallet_now_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/delete_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/export_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/get_wallet_backup_contents_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/import_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/retry_wallet_backup_recovery_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/set_wallet_backup_enabled_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/set_wallet_backup_server_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/watch_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/wallet_backup_failure_mapper.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_settings_cubit.freezed.dart';
part 'backup_settings_state.dart';

class BackupSettingsCubit extends Cubit<BackupSettingsState> {
  final WatchWalletBackupUsecase _watchWalletBackup;
  final SetWalletBackupEnabledUsecase _setWalletBackupEnabled;
  final SetWalletBackupServerUsecase _setWalletBackupServer;
  final BackupWalletNowUsecase _backupWalletNow;
  final DeleteWalletBackupUsecase _deleteWalletBackup;
  final GetWalletBackupContentsUsecase _getContents;
  final RetryWalletBackupRecoveryUsecase _retryRecovery;
  final ExportWalletBackupFileUsecase _exportFile;
  final ImportWalletBackupFileUsecase _importFile;
  final ResumeWalletBackupFileImportUsecase _resumeFileImport;
  final RecoverSelectedWalletBackupFileUsecase _recoverSelectedFile;
  StreamSubscription<Result<WalletBackupState, BackupSettingsFailure>>?
  _walletBackupSubscription;
  Uint8List? _selectedFileBytes;

  BackupSettingsCubit({
    required this._watchWalletBackup,
    required this._setWalletBackupEnabled,
    required this._setWalletBackupServer,
    required this._backupWalletNow,
    required this._deleteWalletBackup,
    required this._getContents,
    required this._retryRecovery,
    required this._exportFile,
    required this._importFile,
    required this._resumeFileImport,
    required this._recoverSelectedFile,
  }) : super(BackupSettingsState());

  Future<void> loadDataBackup() async {
    await _startWalletBackupWatch();
    if (isClosed) return;
    await loadContents();
  }

  Future<void> loadContents() async {
    if (state.contentsLoading) return;
    emit(state.copyWith(contentsLoading: true, failure: null));
    switch (await _getContents.execute()) {
      case Ok(:final value):
        if (!isClosed) {
          emit(state.copyWith(contents: value, contentsLoading: false));
        }
      case Err(:final failure):
        if (!isClosed) {
          emit(state.copyWith(contentsLoading: false, failure: failure));
        }
    }
  }

  Future<void> setWalletBackupEnabled(bool enabled) =>
      _runWalletBackup(() => _setWalletBackupEnabled.execute(enabled));

  Future<void> setWalletBackupServer(String value) =>
      _runWalletBackup(() => _setWalletBackupServer.execute(value));

  Future<void> backupWalletNow() => _runWalletBackup(_backupWalletNow.execute);

  Future<void> deleteWalletBackup() =>
      _runWalletBackup(_deleteWalletBackup.execute);

  Future<void> retryWalletBackupRecovery() async {
    if (!state.canRetryRecovery) return;
    emit(state.copyWith(walletBackupBusy: true, failure: null));
    if (state.walletBackup?.needsAttention ?? false) {
      final result = await _resumeFileImport.execute();
      if (isClosed) return;
      switch (result) {
        case Ok(:final value):
          _selectedFileBytes = value.bytes;
          emit(
            state.copyWith(
              fileComparison: value.comparison,
              walletBackupBusy: false,
            ),
          );
        case Err(:final failure):
          emit(state.copyWith(failure: failure, walletBackupBusy: false));
      }
      return;
    }
    final result = await _retryRecovery.execute();
    if (isClosed) return;
    if (mapWalletBackupRecoveryStatus(result.status) case final failure?) {
      emit(state.copyWith(failure: failure));
    }
    emit(state.copyWith(walletBackupBusy: false));
  }

  Future<void> exportBackupFile({
    required WalletBackupFileProtection protection,
    required bool confirmedUnencrypted,
  }) async {
    if (state.walletBackupBusy) return;
    emit(
      state.copyWith(
        walletBackupBusy: true,
        fileExportReady: false,
        failure: null,
      ),
    );
    final result = await _exportFile.execute(
      protection: protection,
      confirmedUnencrypted: confirmedUnencrypted,
    );
    if (isClosed) return;
    switch (result) {
      case Ok(value: true):
        emit(state.copyWith(fileExportReady: true));
      case Ok():
        break;
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
    emit(state.copyWith(walletBackupBusy: false));
  }

  Future<void> importBackupFile() async {
    if (state.walletBackupBusy) return;
    _selectedFileBytes = null;
    emit(
      state.copyWith(
        walletBackupBusy: true,
        fileComparison: null,
        fileRecoveryResult: null,
        fileExportReady: false,
        failure: null,
      ),
    );
    final result = await _importFile.execute();
    if (isClosed) return;
    switch (result) {
      case Ok(value: null):
        break;
      case Ok(value: final value?):
        _selectedFileBytes = value.bytes;
        emit(state.copyWith(fileComparison: value.comparison));
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
    emit(state.copyWith(walletBackupBusy: false));
  }

  Future<void> recoverSelectedBackup(WalletBackupImportSource source) async {
    final bytes = _selectedFileBytes;
    final comparison = state.fileComparison;
    if (bytes == null ||
        comparison == null ||
        (source == WalletBackupImportSource.server &&
            comparison.server == null) ||
        state.walletBackupBusy) {
      return;
    }
    emit(state.copyWith(walletBackupBusy: true, failure: null));
    final recovery = await _recoverSelectedFile.execute(
      bytes: bytes,
      comparison: comparison,
      source: source,
    );
    if (isClosed) return;
    switch (recovery) {
      case Err(:final failure):
        emit(
          state.copyWith(
            fileComparison: null,
            failure: failure,
            walletBackupBusy: false,
          ),
        );
        return;
      case Ok(
        value: WalletBackupFileReselection(:final bytes, :final comparison),
      ):
        _selectedFileBytes = bytes;
        emit(
          state.copyWith(fileComparison: comparison, walletBackupBusy: false),
        );
        return;
      case Ok(value: WalletBackupFileRecovered(:final result)):
        _selectedFileBytes = null;
        emit(state.copyWith(fileComparison: null, fileRecoveryResult: result));
    }
    await loadContents();
    if (isClosed) return;
    emit(state.copyWith(walletBackupBusy: false));
  }

  void cancelBackupFileImport() {
    _selectedFileBytes = null;
    emit(state.copyWith(fileComparison: null));
  }

  Future<void> _startWalletBackupWatch() async {
    if (_walletBackupSubscription != null) return;
    _walletBackupSubscription = _watchWalletBackup.execute().listen((result) {
      if (isClosed) return;
      switch (result) {
        case Ok(:final value):
          emit(state.copyWith(walletBackup: value));
        case Err(:final failure):
          emit(state.copyWith(failure: failure));
      }
    });
  }

  Future<void> _runWalletBackup(
    Future<Result<void, BackupSettingsFailure>> Function() action,
  ) async {
    if (state.walletBackupBusy) return;
    emit(state.copyWith(walletBackupBusy: true, failure: null));
    final result = await action();
    if (isClosed) return;
    if (result case Err(:final failure)) {
      emit(state.copyWith(failure: failure));
    }
    emit(state.copyWith(walletBackupBusy: false));
  }

  @override
  Future<void> close() async {
    await _walletBackupSubscription?.cancel();
    return super.close();
  }
}
