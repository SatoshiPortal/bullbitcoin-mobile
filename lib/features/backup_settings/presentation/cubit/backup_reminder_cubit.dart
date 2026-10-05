import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_backup_reminders_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class BackupReminderState {
  final bool? disabled;
  final bool saving;
  final BackupReminder? reminder;
  final BackupSettingsFailure? failure;

  const BackupReminderState({
    this.disabled,
    this.saving = false,
    this.reminder,
    this.failure,
  });
}

final class BackupReminderCubit extends Cubit<BackupReminderState> {
  final LoadBackupReminderPreferencesUsecase _loadPreferences;
  final SelectBackupReminderUsecase _selectReminder;
  final DismissBackupReminderUsecase _dismissReminder;
  final SetBackupRemindersDisabledUsecase _setDisabled;
  List<Wallet> _wallets = const [];
  int _revision = 0;
  bool _shownThisSession = false;

  BackupReminderCubit({
    required this._loadPreferences,
    required this._selectReminder,
    required this._dismissReminder,
    required this._setDisabled,
  }) : super(const BackupReminderState());

  Future<void> loadPreferences() async {
    final revision = _revision;
    final result = await _loadPreferences.execute();
    if (isClosed || revision != _revision) return;
    switch (result) {
      case Ok(:final value):
        emit(
          BackupReminderState(
            disabled: value.disabled,
            reminder: state.reminder,
          ),
        );
      case Err(:final failure):
        emit(BackupReminderState(disabled: state.disabled, failure: failure));
    }
  }

  Future<void> evaluate(List<Wallet> wallets) async {
    _wallets = List.unmodifiable(wallets);
    if (_shownThisSession || state.saving) return;
    final revision = ++_revision;
    final result = await _selectReminder.execute(_wallets);
    if (isClosed || revision != _revision || _shownThisSession) return;
    switch (result) {
      case Ok(:final value):
        emit(
          BackupReminderState(
            disabled: value.preferences.disabled,
            reminder: value.reminder,
          ),
        );
      case Err(:final failure):
        emit(BackupReminderState(disabled: state.disabled, failure: failure));
    }
  }

  bool claimReminder(BackupReminder reminder) {
    if (_shownThisSession || state.saving || state.reminder != reminder) {
      return false;
    }
    _shownThisSession = true;
    _revision++;
    emit(BackupReminderState(disabled: state.disabled));
    return true;
  }

  Future<bool> dismiss(BackupReminder reminder) async {
    if (state.saving) return false;
    _revision++;
    emit(BackupReminderState(disabled: state.disabled, saving: true));
    final result = await _dismissReminder.execute(reminder);
    if (isClosed) return false;
    switch (result) {
      case Ok():
        emit(BackupReminderState(disabled: state.disabled));
        return true;
      case Err(:final failure):
        emit(BackupReminderState(disabled: state.disabled, failure: failure));
        return false;
    }
  }

  Future<bool> setDisabled(bool disabled) async {
    if (state.saving) return false;
    _revision++;
    emit(BackupReminderState(disabled: state.disabled, saving: true));
    final result = await _setDisabled.execute(disabled);
    if (isClosed) return false;
    switch (result) {
      case Ok():
        emit(BackupReminderState(disabled: disabled));
        if (!disabled) await evaluate(_wallets);
        return true;
      case Err(:final failure):
        emit(BackupReminderState(disabled: state.disabled, failure: failure));
        return false;
    }
  }
}
