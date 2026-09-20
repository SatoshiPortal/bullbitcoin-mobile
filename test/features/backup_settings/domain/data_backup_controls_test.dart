import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/data_backup_status.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_data_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../vault_recovery_fixture.dart';

class _Backups extends Mock implements WalletBackupFacade {}

void main() {
  late _Backups backups;
  late LoadDataBackupStatusUsecase load;
  setUp(() {
    backups = _Backups();
    load = LoadDataBackupStatusUsecase(backups);
  });

  test('undecided controls do not resolve a credential or job', () async {
    when(
      backups.getControl,
    ).thenAnswer((_) async => const Ok(WalletBackupControl()));
    final result =
        (await load.execute() as Ok<DataBackupStatus, BackupSettingsFailure>)
            .value;
    expect(result.control.enabled, isNull);
    verifyNever(backups.getState);
    verifyNever(() => backups.publicationStatus);
  });

  test(
    'off with an unavailable identity remains usable without inventing a date',
    () async {
      when(
        backups.getControl,
      ).thenAnswer((_) async => const Ok(WalletBackupControl(enabled: false)));
      when(
        backups.getState,
      ).thenAnswer((_) async => const Err(WalletBackupCredentialFailure()));
      final result =
          (await load.execute() as Ok<DataBackupStatus, BackupSettingsFailure>)
              .value;
      expect(result.control.enabled, isFalse);
      expect(result.lastSuccessAt, isNull);
      expect(result.failure, isNull);
      verifyNever(() => backups.publicationStatus);
    },
  );

  test(
    'an unavailable credential keeps the enabled control and its off action',
    () async {
      when(
        backups.getControl,
      ).thenAnswer((_) async => const Ok(WalletBackupControl(enabled: true)));
      when(
        backups.getState,
      ).thenAnswer((_) async => const Err(WalletBackupCredentialFailure()));
      final result =
          (await load.execute() as Ok<DataBackupStatus, BackupSettingsFailure>)
              .value;
      expect(result.control.enabled, isTrue);
      expect(result.failure, isA<BackupSettingsWordsUnavailableFailure>());
      verifyNever(() => backups.publicationStatus);
    },
  );

  test(
    'off retains the current identity last success without reading a job',
    () async {
      final date = DateTime.utc(2026, 9, 19);
      when(
        backups.getControl,
      ).thenAnswer((_) async => const Ok(WalletBackupControl(enabled: false)));
      when(backups.getState).thenAnswer(
        (_) async => Ok(
          WalletBackupState(
            identity: 'a' * 64,
            enabled: false,
            checkpoint: WalletBackupCheckpoint(
              generation: 1,
              etag: 'b' * 64,
              ciphertextHash: 'c' * 64,
            ),
            lastSuccessAt: date,
          ),
        ),
      );
      final result =
          (await load.execute() as Ok<DataBackupStatus, BackupSettingsFailure>)
              .value;
      expect(result.lastSuccessAt, date);
      expect(result.control.enabled, isFalse);
      expect(result.publication, isNull);
      expect(result.isUpToDate, isFalse);
      verifyNever(() => backups.publicationStatus);
      verifyNever(backups.resumeAutomatic);
      verifyNever(backups.retryAutomatic);
    },
  );

  for (final enabled in [null, false, true]) {
    for (final incomplete in [false, true]) {
      test(
        'retry respects consent $enabled and recovery fence $incomplete',
        () async {
          when(backups.getControl).thenAnswer(
            (_) async => Ok(
              WalletBackupControl(
                enabled: enabled,
                recoveryIncomplete: incomplete,
              ),
            ),
          );
          when(backups.getState).thenAnswer(
            (_) async => Ok(
              WalletBackupState(
                identity: 'a' * 64,
                enabled: enabled,
                recoveryIncomplete: incomplete,
              ),
            ),
          );
          when(
            () => backups.publicationStatus,
          ).thenReturn(const WalletBackupJobStatus());
          expect(await load.execute(retryPublication: true), isA<Ok>());
          if (enabled == true && !incomplete) {
            verify(backups.retryAutomatic).called(1);
          } else {
            verifyNever(backups.retryAutomatic);
          }
          verifyNever(backups.resumeAutomatic);
        },
      );
    }
  }

  test('off during status read wins over a stale successful job', () async {
    when(
      backups.getControl,
    ).thenAnswer((_) async => const Ok(WalletBackupControl(enabled: true)));
    when(backups.getState).thenAnswer(
      (_) async => Ok(WalletBackupState(identity: 'a' * 64, enabled: false)),
    );
    final result =
        (await load.execute() as Ok<DataBackupStatus, BackupSettingsFailure>)
            .value;
    expect(result.control.enabled, isFalse);
    expect(result.publication, isNull);
    verifyNever(() => backups.publicationStatus);
  });

  test(
    'current identity checkpoint is required before displaying a success date',
    () async {
      when(
        backups.getControl,
      ).thenAnswer((_) async => const Ok(WalletBackupControl(enabled: true)));
      when(backups.getState).thenAnswer(
        (_) async => Ok(WalletBackupState(identity: 'a' * 64, enabled: true)),
      );
      when(() => backups.publicationStatus).thenReturn(
        const WalletBackupJobStatus(
          result: Ok(WalletBackupPublication.published),
        ),
      );
      final result =
          (await load.execute() as Ok<DataBackupStatus, BackupSettingsFailure>)
              .value;
      expect(result.lastSuccessAt, isNull);
      expect(result.isUpToDate, isFalse);
    },
  );

  test(
    'conflict remains actionable instead of becoming an unexpected error',
    () async {
      when(
        backups.getControl,
      ).thenAnswer((_) async => const Ok(WalletBackupControl(enabled: true)));
      when(backups.getState).thenAnswer(
        (_) async => Ok(WalletBackupState(identity: 'a' * 64, enabled: true)),
      );
      when(() => backups.publicationStatus).thenReturn(
        const WalletBackupJobStatus(result: Err(WalletBackupConflictFailure())),
      );
      final result =
          (await load.execute() as Ok<DataBackupStatus, BackupSettingsFailure>)
              .value;
      expect(result.failure, isA<BackupSettingsConflictFailure>());
    },
  );

  test(
    'cancelled replace does not publish; accepted replacement keeps its inspection',
    () async {
      final inspection = vaultRecoveryFixture().inspection;
      final publish = PublishDataBackupUsecase(backups);
      expect(
        await publish.execute(replace: inspection, confirmed: false),
        isA<Err>(),
      );
      verifyZeroInteractions(backups);
      when(
        () => backups.publish(force: true, replace: inspection),
      ).thenAnswer((_) async => const Ok(WalletBackupPublication.published));
      expect(
        await publish.execute(replace: inspection, confirmed: true),
        isA<Ok>(),
      );
      verify(() => backups.publish(force: true, replace: inspection)).called(1);
    },
  );

  test('cancelled delete makes no owner call', () async {
    expect(
      await DeleteDataBackupUsecase(backups).execute(confirmed: false),
      isA<Err>(),
    );
    verifyZeroInteractions(backups);
  });
}
