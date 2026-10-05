import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/backup_reminder_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_backup_reminders_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_reminder_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../reminder_fixture.dart';

void main() {
  late _Repository repository;
  final wallets = [reminderWallet(physical: DateTime.utc(2020))];

  setUp(() => repository = _Repository());
  BackupReminderCubit buildCubit() => BackupReminderCubit(
    loadPreferences: LoadBackupReminderPreferencesUsecase(repository),
    selectReminder: SelectBackupReminderUsecase(repository),
    dismissReminder: DismissBackupReminderUsecase(repository),
    setDisabled: SetBackupRemindersDisabledUsecase(repository),
  );

  blocTest<BackupReminderCubit, BackupReminderState>(
    'claims at most one reminder per session',
    build: buildCubit,
    act: (cubit) async {
      await cubit.evaluate(wallets);
      expect(cubit.claimReminder(BackupReminder.testPhysicalBackup), isTrue);
      await cubit.evaluate(wallets);
      expect(cubit.claimReminder(BackupReminder.testPhysicalBackup), isFalse);
    },
    expect: () => [
      isA<BackupReminderState>().having(
        (state) => state.reminder,
        'reminder',
        BackupReminder.testPhysicalBackup,
      ),
      isA<BackupReminderState>().having(
        (state) => state.reminder,
        'reminder',
        isNull,
      ),
    ],
  );

  blocTest<BackupReminderCubit, BackupReminderState>(
    'disabling suppresses reminders and re-enabling selects a due reminder',
    build: buildCubit,
    act: (cubit) async {
      await cubit.loadPreferences();
      expect(await cubit.setDisabled(true), isTrue);
      await cubit.evaluate(wallets);
      expect(cubit.state.disabled, isTrue);
      expect(cubit.state.reminder, isNull);
      expect(await cubit.setDisabled(false), isTrue);
    },
    verify: (cubit) {
      expect(cubit.state.disabled, isFalse);
      expect(cubit.state.reminder, BackupReminder.testPhysicalBackup);
    },
  );

  blocTest<BackupReminderCubit, BackupReminderState>(
    'failed writes report failure and keep the prior preference',
    build: buildCubit,
    act: (cubit) async {
      await cubit.loadPreferences();
      repository.failWrites = true;
      expect(await cubit.setDisabled(true), isFalse);
      expect(cubit.state.disabled, isFalse);
      expect(cubit.state.failure, isA<BackupSettingsUnexpectedFailure>());
      expect(await cubit.dismiss(BackupReminder.testPhysicalBackup), isFalse);
    },
    verify: (cubit) {
      expect(cubit.state.disabled, isFalse);
      expect(cubit.state.failure, isA<BackupSettingsUnexpectedFailure>());
      expect(cubit.state.saving, isFalse);
    },
  );

  blocTest<BackupReminderCubit, BackupReminderState>(
    'a pending selection cannot undo a newer disable action',
    build: buildCubit,
    act: (cubit) async {
      final pending =
          Completer<Result<BackupReminderPreferences, BackupSettingsFailure>>();
      repository.pendingLoad = pending;
      final evaluating = cubit.evaluate(wallets);
      await cubit.setDisabled(true);
      pending.complete(const Ok(BackupReminderPreferences()));
      await evaluating;
    },
    verify: (cubit) {
      expect(cubit.state.disabled, isTrue);
      expect(cubit.state.reminder, isNull);
    },
  );
}

class _Repository extends Fake implements BackupReminderRepository {
  bool disabled = false;
  bool failWrites = false;
  Completer<Result<BackupReminderPreferences, BackupSettingsFailure>>?
  pendingLoad;

  @override
  Future<Result<BackupReminderPreferences, BackupSettingsFailure>>
  load() async {
    final pending = pendingLoad;
    pendingLoad = null;
    return pending != null
        ? pending.future
        : Ok(BackupReminderPreferences(disabled: disabled));
  }

  @override
  Future<Result<void, BackupSettingsFailure>> setDisabled(bool value) async {
    if (failWrites) return const Err(BackupSettingsUnexpectedFailure());
    disabled = value;
    return const Ok(null);
  }

  @override
  Future<Result<void, BackupSettingsFailure>> snooze(
    BackupReminder reminder,
    DateTime until,
  ) async => failWrites
      ? const Err(BackupSettingsUnexpectedFailure())
      : const Ok(null);
}
