import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_backup_reminders_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class BackupReminderState {
  final BackupReminder? reminder;
  final bool dismissForever;
  final BackupSettingsFailure? failure;

  const BackupReminderState({
    this.reminder,
    this.dismissForever = false,
    this.failure,
  });
}

final class BackupReminderCubit extends Cubit<BackupReminderState> {
  final LoadBackupReminderPreferencesUsecase _loadPreferences;
  final SelectBackupReminderUsecase _selectReminder;
  final DismissBackupReminderUsecase _dismissReminder;
  final SetBackupRemindersDismissedUsecase _setDismissed;
  bool _sessionConsumed = false;
  Future<void>? _initialLoad;
  Future<void>? _evaluation;
  List<Wallet>? _pendingWallets;

  BackupReminderCubit(
    this._loadPreferences,
    this._selectReminder,
    this._dismissReminder,
    this._setDismissed,
  ) : super(const BackupReminderState());

  Future<void> load() => _initialLoad ??= _load();

  Future<void> _load() async {
    final result = await _loadPreferences.execute();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(BackupReminderState(dismissForever: value.dismissForever));
      case Err(:final failure):
        emit(BackupReminderState(failure: failure));
    }
  }

  Future<void> evaluate(List<Wallet> wallets) {
    if (_sessionConsumed) return Future.value();
    _pendingWallets = List.unmodifiable(wallets);
    final current = _evaluation;
    if (current != null) return current;

    final evaluation = _evaluatePending();
    _evaluation = evaluation;
    return evaluation.whenComplete(() {
      if (identical(_evaluation, evaluation)) _evaluation = null;
    });
  }

  Future<void> _evaluatePending() async {
    await load();
    while (!isClosed && !_sessionConsumed && _pendingWallets != null) {
      final wallets = _pendingWallets!;
      _pendingWallets = null;
      final selection = await _selectReminder.execute(wallets);
      if (isClosed) return;
      if (_pendingWallets != null) continue;
      switch (selection) {
        case Ok(:final value):
          if (value == null) continue;
          _sessionConsumed = true;
          emit(
            BackupReminderState(
              reminder: value,
              dismissForever: state.dismissForever,
            ),
          );
        case Err(:final failure):
          emit(
            BackupReminderState(
              dismissForever: state.dismissForever,
              failure: failure,
            ),
          );
      }
    }
  }

  Future<void> dismissCurrent() async {
    final reminder = state.reminder;
    if (reminder == null) return;
    final result = await _dismissReminder.execute(reminder);
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(BackupReminderState(dismissForever: state.dismissForever));
      case Err(:final failure):
        emit(
          BackupReminderState(
            dismissForever: state.dismissForever,
            failure: failure,
          ),
        );
    }
  }

  void actionOpened() =>
      emit(BackupReminderState(dismissForever: state.dismissForever));

  Future<void> setDismissForever(bool value) async {
    final result = await _setDismissed.execute(value);
    if (isClosed) return;
    switch (result) {
      case Ok():
        if (value) {
          _sessionConsumed = true;
          _pendingWallets = null;
        }
        emit(BackupReminderState(dismissForever: value));
      case Err(:final failure):
        emit(
          BackupReminderState(
            dismissForever: state.dismissForever,
            failure: failure,
          ),
        );
    }
  }
}
