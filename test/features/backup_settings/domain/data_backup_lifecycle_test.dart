import 'dart:async';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/update_data_backup_lifecycle_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Backups extends Mock implements WalletBackupFacade {}

void main() {
  late _Backups backups;
  late UpdateDataBackupLifecycleUsecase lifecycle;
  setUp(() {
    backups = _Backups();
    when(backups.stopAutomatic).thenAnswer((_) async {});
    lifecycle = UpdateDataBackupLifecycleUsecase(backups);
  });
  test(
    'startup without a ready wallet stops without even reading consent',
    () async {
      await lifecycle.execute(ready: false, foreground: true);
      verify(backups.stopAutomatic).called(1);
      verifyNever(backups.getControl);
      verifyNever(backups.resumeAutomatic);
    },
  );
  for (final enabled in [null, false, true]) {
    test(
      'ready startup with consent $enabled uses the existing watcher',
      () async {
        when(
          backups.getControl,
        ).thenAnswer((_) async => Ok(WalletBackupControl(enabled: enabled)));
        await lifecycle.execute(ready: true, foreground: true);
        if (enabled == true) {
          verify(backups.resumeAutomatic).called(1);
          verifyNever(backups.stopAutomatic);
        } else {
          verify(backups.stopAutomatic).called(1);
          verifyNever(backups.resumeAutomatic);
        }
      },
    );
  }
  test('off stops the previously started watcher', () async {
    when(
      backups.getControl,
    ).thenAnswer((_) async => const Ok(WalletBackupControl(enabled: true)));
    await lifecycle.execute(ready: true, foreground: true);
    when(
      backups.getControl,
    ).thenAnswer((_) async => const Ok(WalletBackupControl(enabled: false)));
    await lifecycle.execute(ready: true, foreground: true);
    verify(backups.resumeAutomatic).called(1);
    verify(backups.stopAutomatic).called(1);
  });
  test(
    'a stale enabled read cannot restart work after backgrounding',
    () async {
      final pending =
          Completer<Result<WalletBackupControl, WalletBackupFailure>>();
      when(backups.getControl).thenAnswer((_) => pending.future);
      final checking = lifecycle.execute(ready: true, foreground: true);
      await lifecycle.execute(ready: true, foreground: false);
      pending.complete(const Ok(WalletBackupControl(enabled: true)));
      await checking;
      verifyNever(backups.resumeAutomatic);
      verify(backups.stopAutomatic).called(1);
    },
  );
  test(
    'unreadable consent stops rather than guessing that it was enabled',
    () async {
      when(
        backups.getControl,
      ).thenAnswer((_) async => const Err(WalletBackupStorageFailure()));
      await lifecycle.execute(ready: true, foreground: true);
      verify(backups.stopAutomatic).called(1);
      verifyNever(backups.resumeAutomatic);
    },
  );
}
