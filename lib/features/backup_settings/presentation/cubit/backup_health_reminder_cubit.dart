import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_health_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/acknowledge_backup_health_reminder_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/evaluate_backup_health_reminder_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/start_backup_health_action_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'backup_health_reminder_state.dart';

class BackupHealthReminderCubit extends Cubit<BackupHealthReminderState> {
  final EvaluateBackupHealthReminderUsecase _evaluateUsecase;
  final AcknowledgeBackupHealthReminderUsecase _acknowledgeUsecase;
  final StartBackupHealthActionUsecase _startActionUsecase;

  BackupHealthReminderCubit(
    this._evaluateUsecase,
    this._acknowledgeUsecase,
    this._startActionUsecase,
  ) : super(const BackupHealthReminderHidden());

  List<Wallet> _wallets = const [];
  int _arkBalanceSat = 0;
  bool _isEvaluating = false;
  bool _evaluationQueued = false;
  bool _sessionSuppressed = false;

  Future<void> evaluate({
    required List<Wallet> wallets,
    required int arkBalanceSat,
  }) async {
    _wallets = List.unmodifiable(wallets);
    _arkBalanceSat = arkBalanceSat;
    if (_sessionSuppressed) return;

    if (_isEvaluating) {
      _evaluationQueued = true;
      return;
    }

    _isEvaluating = true;
    try {
      do {
        _evaluationQueued = false;
        final result = await _evaluateUsecase.execute(
          wallets: _wallets,
          arkBalanceSat: _arkBalanceSat,
        );
        if (isClosed || _sessionSuppressed) return;
        switch (result) {
          case Ok(:final value):
            emit(
              value == null
                  ? const BackupHealthReminderHidden()
                  : BackupHealthReminderVisible(decision: value),
            );
          case Err():
            if (state is! BackupHealthReminderVisible) {
              emit(const BackupHealthReminderHidden());
            }
        }
      } while (_evaluationQueued);
    } finally {
      _isEvaluating = false;
    }
  }

  Future<void> reevaluate() async {
    if (_wallets.isEmpty) return;
    await evaluate(wallets: _wallets, arkBalanceSat: _arkBalanceSat);
  }

  Future<void> acknowledge() async {
    final current = state;
    if (current is! BackupHealthReminderVisible || current.isSaving) return;

    emit(current.copyWith(isSaving: true, clearFailure: true));
    final result = await _acknowledgeUsecase.execute(current.decision);
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(const BackupHealthReminderHidden());
      case Err(:final failure):
        emit(current.copyWith(isSaving: false, failure: failure));
    }
  }

  Future<bool> startRecommendedAction() async {
    final current = state;
    if (current is! BackupHealthReminderVisible || current.isSaving) {
      return false;
    }

    emit(current.copyWith(isSaving: true, clearFailure: true));
    final result = await _startActionUsecase.execute(current.decision);
    if (isClosed) return false;
    switch (result) {
      case Ok():
        _sessionSuppressed = true;
        emit(const BackupHealthReminderHidden());
        return true;
      case Err(:final failure):
        emit(current.copyWith(isSaving: false, failure: failure));
        return false;
    }
  }

  void dismissFailureForSession() {
    final current = state;
    if (current is! BackupHealthReminderVisible ||
        current.failure == null ||
        current.isSaving) {
      return;
    }

    _sessionSuppressed = true;
    emit(const BackupHealthReminderHidden());
  }
}
