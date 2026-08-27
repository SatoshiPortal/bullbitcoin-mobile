import 'dart:async';

import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/backup_wallet_now_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/delete_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/get_wallet_backup_recovery_outcome_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/get_wallet_backup_contents_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/retry_wallet_backup_recovery_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/set_wallet_backup_enabled_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/watch_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_settings_cubit.freezed.dart';
part 'backup_settings_state.dart';

class BackupSettingsCubit extends Cubit<BackupSettingsState> {
  final GetWalletsUsecase _getWalletsUsecase;
  final SettingsRepository _settingsRepository;
  final WatchWalletBackupUsecase _watchWalletBackup;
  final SetWalletBackupEnabledUsecase _setWalletBackupEnabled;
  final BackupWalletNowUsecase _backupWalletNow;
  final DeleteWalletBackupUsecase _deleteWalletBackup;
  final GetWalletBackupRecoveryOutcomeUsecase _getRecoveryOutcome;
  final GetWalletBackupContentsUsecase _getContents;
  final RetryWalletBackupRecoveryUsecase _retryRecovery;
  StreamSubscription<Result<WalletBackupState, BackupSettingsFailure>>?
  _walletBackupSubscription;

  BackupSettingsCubit({
    required this._getWalletsUsecase,
    required this._settingsRepository,
    required this._watchWalletBackup,
    required this._setWalletBackupEnabled,
    required this._backupWalletNow,
    required this._deleteWalletBackup,
    required this._getRecoveryOutcome,
    required this._getContents,
    required this._retryRecovery,
  }) : super(BackupSettingsState());

  Future<void> checkBackupStatus() async {
    await _startWalletBackupWatch();
    await _loadRecoveryOutcome();
    await loadContents();
    try {
      emit(state.copyWith(status: BackupSettingsStatus.loading));

      final defaultWallets = await _getWalletsUsecase.execute(
        onlyDefaults: true,
      );
      if (defaultWallets.isEmpty) {
        emit(state.copyWith(status: BackupSettingsStatus.success));
        return;
      }
      final isDefaultPhysicalBackupTested = defaultWallets.every(
        (e) => e.isPhysicalBackupTested,
      );
      final isDefaultEncryptedBackupTested = defaultWallets.every(
        (e) => e.isEncryptedVaultTested,
      );

      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final network = Network.fromEnvironment(
        isTestnet: environment.isTestnet,
        isLiquid: false,
      );

      final lastPhysicalBackup = defaultWallets
          .firstWhere((e) => e.network == network)
          .latestPhysicalBackup;
      final lastEncryptedBackup = defaultWallets
          .firstWhere((e) => e.network == network)
          .latestEncryptedBackup;
      emit(
        state.copyWith(
          isDefaultPhysicalBackupTested: isDefaultPhysicalBackupTested,
          isDefaultEncryptedBackupTested: isDefaultEncryptedBackupTested,
          lastPhysicalBackup: lastPhysicalBackup,
          lastEncryptedBackup: lastEncryptedBackup,
          status: BackupSettingsStatus.success,
          failure: null,
        ),
      );
    } catch (e) {
      log.warning('checkBackupStatus failed', error: e);
      emit(
        state.copyWith(
          status: BackupSettingsStatus.error,
          failure: BackupSettingsUnexpectedFailure(e.toString()),
        ),
      );
    }
  }

  Future<void> loadContents() async {
    if (state.contentsLoading) return;
    emit(state.copyWith(contentsLoading: true));
    switch (await _getContents.execute()) {
      case Ok(:final value):
        if (!isClosed) {
          emit(state.copyWith(contents: value, contentsLoading: false));
        }
      case Err():
        if (!isClosed) {
          emit(state.copyWith(contentsLoading: false));
        }
    }
  }

  Future<void> setWalletBackupEnabled(bool enabled) => _runWalletBackup(
    WalletBackupSettingsOperation.saving,
    () => _setWalletBackupEnabled.execute(enabled),
  );

  Future<void> backupWalletNow() => _runWalletBackup(
    WalletBackupSettingsOperation.backingUp,
    _backupWalletNow.execute,
  );

  Future<void> deleteWalletBackup() => _runWalletBackup(
    WalletBackupSettingsOperation.deleting,
    _deleteWalletBackup.execute,
  );

  Future<void> retryWalletBackupRecovery() async {
    if (!state.canRetryRecovery) return;
    emit(
      state.copyWith(
        walletBackupOperation: WalletBackupSettingsOperation.recovering,
        failure: null,
      ),
    );
    final result = await _retryRecovery.execute();
    await _loadRecoveryOutcome();
    if (result.status != WalletBackupRecoveryStatus.restored &&
        result.status != WalletBackupRecoveryStatus.noBackup) {
      emit(state.copyWith(failure: const BackupSettingsUnexpectedFailure()));
    }
    emit(
      state.copyWith(walletBackupOperation: WalletBackupSettingsOperation.idle),
    );
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

  Future<void> _loadRecoveryOutcome() async {
    switch (await _getRecoveryOutcome.execute()) {
      case Ok(:final value):
        if (!isClosed) emit(state.copyWith(lastRecoveryOutcome: value));
      case Err():
        // Recovery history is auxiliary to the live backup controls.
        return;
    }
  }

  Future<void> _runWalletBackup(
    WalletBackupSettingsOperation operation,
    Future<Result<void, BackupSettingsFailure>> Function() action,
  ) async {
    if (state.walletBackupBusy) return;
    emit(state.copyWith(walletBackupOperation: operation, failure: null));
    final result = await action();
    if (result case Err(:final failure)) {
      emit(state.copyWith(failure: failure));
    }
    emit(
      state.copyWith(walletBackupOperation: WalletBackupSettingsOperation.idle),
    );
  }

  @override
  Future<void> close() async {
    await _walletBackupSubscription?.cancel();
    return super.close();
  }
}
