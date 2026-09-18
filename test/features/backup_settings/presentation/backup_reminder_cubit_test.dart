import 'dart:async';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/backup_reminder_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_backup_reminders_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_reminder_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _Repository repository;
  late BackupReminderCubit cubit;
  final wallets = [
    Wallet(
      origin: 'default',
      network: Network.bitcoinMainnet,
      isDefault: true,
      signers: [
        WalletSigner.single(
          masterFingerprint: 'deadbeef',
          xpubFingerprint: 'cafebabe',
          xpub: 'xpub',
          signer: SignerEntity.local,
          signerDevice: null,
        ),
      ],
      scriptType: ScriptType.bip84,
      publicDescriptor: 'wpkh(xpub/<0;1>/*)',
      balanceSat: BigInt.one,
    ),
  ];

  setUp(() {
    repository = _Repository();
    cubit = BackupReminderCubit(
      loadPreferences: LoadBackupReminderPreferencesUsecase(repository),
      selectReminder: SelectBackupReminderUsecase(repository),
      dismissReminder: DismissBackupReminderUsecase(repository),
      setDisabled: SetBackupRemindersDisabledUsecase(repository),
    );
  });
  tearDown(() => cubit.close());

  test('one dialog per session, including action or cancellation', () async {
    await cubit.evaluate(wallets);
    expect(cubit.state.reminder, BackupReminder.noTestedBackup);
    expect(cubit.claimReminder(BackupReminder.noTestedBackup), isTrue);
    await cubit.evaluate(wallets);
    expect(cubit.state.reminder, isNull);
    expect(cubit.claimReminder(BackupReminder.noTestedBackup), isFalse);
    expect(repository.writes, 0);
  });

  test(
    'disable and re-enable persist without erasing snooze choices',
    () async {
      await cubit.loadPreferences();
      expect(cubit.state.disabled, isFalse);
      expect(await cubit.setDisabled(true), isTrue);
      await cubit.evaluate(wallets);
      expect(cubit.state.disabled, isTrue);
      expect(cubit.state.reminder, isNull);
      expect(await cubit.setDisabled(false), isTrue);
      expect(cubit.state.disabled, isFalse);
      expect(cubit.state.reminder, BackupReminder.noTestedBackup);
      expect(repository.writes, 2);
    },
  );

  test(
    'a failed preference write reports failure and keeps the prior choice',
    () async {
      await cubit.loadPreferences();
      repository.failWrites = true;
      expect(await cubit.setDisabled(true), isFalse);
      expect(cubit.state.disabled, isFalse);
      expect(cubit.state.failure, isA<BackupSettingsFailure>());
      expect(await cubit.dismiss(BackupReminder.testPhysicalBackup), isFalse);
    },
  );

  test('a pending selection cannot undo a newer disable action', () async {
    final pending =
        Completer<Result<BackupReminderPreferences, BackupSettingsFailure>>();
    repository.pendingLoad = pending;
    final evaluating = cubit.evaluate(wallets);
    await cubit.setDisabled(true);
    pending.complete(const Ok(BackupReminderPreferences()));
    await evaluating;
    expect(cubit.state.disabled, isTrue);
    expect(cubit.state.reminder, isNull);
  });

  test('cycle dismissals snooze from now by their own full interval', () async {
    final now = DateTime.utc(2026, 9, 18);
    final dismiss = DismissBackupReminderUsecase(repository);
    for (final entry in {
      BackupReminder.addPhysicalBackup: 180,
      BackupReminder.testPhysicalBackup: 365,
      BackupReminder.testEncryptedVault: 366,
    }.entries) {
      expect(
        await dismiss.execute(entry.key, now: now),
        isA<Ok<void, BackupSettingsFailure>>(),
      );
      expect(repository.lastSnooze, (
        entry.key,
        now.add(Duration(days: entry.value)),
      ));
    }
    await dismiss.execute(BackupReminder.largeBalanceNeedsPhysicalBackup);
    expect(repository.largeBalanceDismissed, isTrue);
  });
}

class _Repository implements BackupReminderRepository {
  bool disabled = false;
  bool failWrites = false;
  bool largeBalanceDismissed = false;
  int writes = 0;
  (BackupReminder, DateTime)? lastSnooze;
  Completer<Result<BackupReminderPreferences, BackupSettingsFailure>>?
  pendingLoad;

  @override
  Future<Result<BackupReminderPreferences, BackupSettingsFailure>>
  load() async {
    final pending = pendingLoad;
    pendingLoad = null;
    if (pending != null) return pending.future;
    return Ok(BackupReminderPreferences(disabled: disabled));
  }

  @override
  Future<Result<void, BackupSettingsFailure>> setDisabled(bool value) async {
    writes++;
    if (failWrites) return const Err(BackupSettingsUnexpectedFailure());
    disabled = value;
    return const Ok(null);
  }

  @override
  Future<Result<void, BackupSettingsFailure>>
  dismissLargeBalanceWarning() async {
    writes++;
    if (failWrites) return const Err(BackupSettingsUnexpectedFailure());
    largeBalanceDismissed = true;
    return const Ok(null);
  }

  @override
  Future<Result<void, BackupSettingsFailure>> snooze(
    BackupReminder reminder,
    DateTime until,
  ) async {
    writes++;
    if (failWrites) return const Err(BackupSettingsUnexpectedFailure());
    lastSnooze = (reminder, until);
    return const Ok(null);
  }
}
