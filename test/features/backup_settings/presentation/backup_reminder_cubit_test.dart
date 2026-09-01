import 'dart:async';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/backup_reminder_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_backup_reminders_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_reminder_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses one reminder slot for the entire app process', () async {
    final repository = _Repository();
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    final wallet = _wallet(balance: 1);

    await cubit.evaluate([wallet]);
    expect(cubit.state.reminder, BackupReminder.noTestedBackup);

    await cubit.dismissCurrent();
    await cubit.evaluate([wallet]);
    expect(cubit.state.reminder, isNull);
  });

  test('turning reminders back on preserves every stored clock', () async {
    final repository = _Repository(
      BackupReminderPreferences(
        dismissForever: true,
        addPhysicalSnoozedUntil: DateTime.utc(2027),
        physicalTestSnoozedUntil: DateTime.utc(2028),
        encryptedVaultTestSnoozedUntil: DateTime.utc(2029),
      ),
    );
    final cubit = _cubit(repository);
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.setDismissForever(false);

    expect(cubit.state.dismissForever, isFalse);
    expect(repository.preferences.addPhysicalSnoozedUntil, DateTime.utc(2027));
    expect(repository.preferences.physicalTestSnoozedUntil, DateTime.utc(2028));
    expect(
      repository.preferences.encryptedVaultTestSnoozedUntil,
      DateTime.utc(2029),
    );
  });

  test('waits for initial preferences before evaluating', () async {
    final load = Completer<void>();
    final repository = _Repository()..loadGate = load.future;
    final cubit = _cubit(repository);
    addTearDown(cubit.close);

    final loading = cubit.load();
    final evaluating = cubit.evaluate([_wallet(balance: 1)]);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.reminder, isNull);

    load.complete();
    await Future.wait([loading, evaluating]);
    expect(cubit.state.reminder, BackupReminder.noTestedBackup);
  });

  test('concurrent evaluations use the latest wallet snapshot once', () async {
    final load = Completer<void>();
    final repository = _Repository()..loadGate = load.future;
    final cubit = _cubit(repository);
    addTearDown(cubit.close);

    final first = cubit.evaluate([_wallet(balance: 0)]);
    final second = cubit.evaluate([_wallet(balance: 1)]);
    load.complete();
    await Future.wait([first, second]);

    expect(repository.loadCount, 2);
    expect(cubit.state.reminder, BackupReminder.noTestedBackup);
    await cubit.dismissCurrent();
    await cubit.evaluate([_wallet(balance: 1)]);
    expect(cubit.state.reminder, isNull);
  });

  test('does not emit when closed during reminder selection', () async {
    final repository = _Repository();
    final cubit = _cubit(repository);
    await cubit.load();
    final selection = Completer<void>();
    repository.loadGate = selection.future;

    final evaluation = cubit.evaluate([_wallet(balance: 1)]);
    await Future<void>.delayed(Duration.zero);
    await cubit.close();
    selection.complete();
    await evaluation;

    expect(cubit.state.reminder, isNull);
  });

  test('discards an in-flight selection when newer wallets arrive', () async {
    final repository = _Repository();
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    final selection = Completer<void>();
    repository.loadGate = selection.future;

    final first = cubit.evaluate([_wallet(balance: 1)]);
    await Future<void>.delayed(Duration.zero);
    final second = cubit.evaluate([_wallet(balance: 0)]);
    selection.complete();
    await Future.wait([first, second]);

    expect(repository.loadCount, 3);
    expect(cubit.state.reminder, isNull);
  });

  test('permanent dismissal discards an in-flight selection', () async {
    final repository = _Repository();
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    final selection = Completer<void>();
    repository.loadGate = selection.future;

    final evaluation = cubit.evaluate([_wallet(balance: 1)]);
    await Future<void>.delayed(Duration.zero);
    await cubit.setDismissForever(true);
    selection.complete();
    await evaluation;

    expect(cubit.state.dismissForever, isTrue);
    expect(cubit.state.reminder, isNull);
  });

  test('preference read failure suppresses reminders for safety', () async {
    final repository = _Repository()..loadFailure = true;
    final cubit = _cubit(repository);
    addTearDown(cubit.close);

    await cubit.evaluate([_wallet(balance: 1)]);

    expect(cubit.state.reminder, isNull);
    expect(cubit.state.failure, isA<BackupSettingsUnexpectedFailure>());
  });
}

BackupReminderCubit _cubit(BackupReminderRepository repository) =>
    BackupReminderCubit(
      LoadBackupReminderPreferencesUsecase(repository),
      SelectBackupReminderUsecase(repository),
      DismissBackupReminderUsecase(repository),
      SetBackupRemindersDismissedUsecase(repository),
    );

Wallet _wallet({required int balance}) => Wallet(
  origin: 'default-bitcoin',
  network: Network.bitcoinMainnet,
  isDefault: true,
  xpubFingerprint: '12345678',
  scriptType: ScriptType.bip84,
  xpub: 'xpub',
  externalPublicDescriptor: 'wpkh(xpub/0/*)',
  internalPublicDescriptor: 'wpkh(xpub/1/*)',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(balance),
);

final class _Repository implements BackupReminderRepository {
  BackupReminderPreferences preferences;
  Future<void>? loadGate;
  int loadCount = 0;
  bool loadFailure = false;

  _Repository([this.preferences = const BackupReminderPreferences()]);

  @override
  Future<Result<BackupReminderPreferences, BackupSettingsFailure>>
  load() async {
    loadCount++;
    await loadGate;
    if (loadFailure) return const Err(BackupSettingsUnexpectedFailure());
    return Ok(preferences);
  }

  @override
  Future<Result<void, BackupSettingsFailure>> setDismissForever(
    bool value,
  ) async {
    preferences = BackupReminderPreferences(
      dismissForever: value,
      largeBalanceWarningDismissed: preferences.largeBalanceWarningDismissed,
      addPhysicalSnoozedUntil: preferences.addPhysicalSnoozedUntil,
      physicalTestSnoozedUntil: preferences.physicalTestSnoozedUntil,
      encryptedVaultTestSnoozedUntil:
          preferences.encryptedVaultTestSnoozedUntil,
    );
    return const Ok(null);
  }

  @override
  Future<Result<void, BackupSettingsFailure>>
  dismissLargeBalanceWarning() async => const Ok(null);

  @override
  Future<Result<void, BackupSettingsFailure>> snooze(
    BackupReminder reminder,
    DateTime until,
  ) async => const Ok(null);
}
