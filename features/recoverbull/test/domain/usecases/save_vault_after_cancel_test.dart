import 'dart:async';

import 'package:bull_recoverbull/src/data/recoverbull_backup_status_writer.dart';
import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/pending_vault_backup.dart';
import 'package:bull_recoverbull/src/domain/entities/recoverbull_network.dart';
import 'package:bull_recoverbull/src/domain/entities/vault_provider.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/repositories/recoverbull_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/google_drive/save_to_google_drive_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/save_file_to_system_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/save_vault_to_provider_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../../support/log_sink.dart';

class _Files extends Mock implements SaveFileToSystemUsecase {}

class _Connect extends Mock implements ConnectToGoogleDriveUsecase {}

class _Drive extends Mock implements SaveVaultToGoogleDriveUsecase {}

class _Status extends Mock implements RecoverBullRepository {}

void main() {
  late _Files files;
  late _Status status;
  late PendingVaultBackup pending;
  late bool canceled;
  late bool disposed;

  setUp(() {
    files = _Files();
    status = _Status();
    pending = PendingVaultBackup(
      vault: EncryptedVault(
        id: List.filled(32, '00').join(),
        salt: List.filled(16, '00').join(),
        ciphertext: List.filled(64, 0),
        createdAt: DateTime.utc(2026),
      ),
      network: RecoverBullNetwork.mainnet,
    );
    canceled = false;
    disposed = false;
    when(
      () => status.markBackupStored(RecoverBullNetwork.mainnet),
    ).thenAnswer((_) async => const Ok(null));
  });

  SaveVaultToProviderUsecase workflow() => SaveVaultToProviderUsecase(
    log: const TestLogSink(),
    saveFile: files,
    connectDrive: _Connect(),
    saveDrive: _Drive(),
    advisoryAvailable: () => !disposed,
    lifecycle: RecoverBullBackupStatusWriter(
      repository: status,
      isDisposed: () => disposed,
      log: const TestLogSink(),
    ),
  );

  test(
    'successful provider save records status after route cancellation',
    () async {
      final completed = Completer<Result<Null, RecoverBullFailure>>();
      final started = Completer<void>();
      when(() => files.execute(vault: pending.vault)).thenAnswer((_) {
        started.complete();
        return completed.future;
      });
      final save = workflow().execute(
        pending: pending,
        provider: VaultProvider.customLocation,
        cancelled: () => canceled,
      );
      await started.future;
      canceled = true;
      completed.complete(const Ok(null));
      expect(await save, isA<Ok<PendingVaultBackup, RecoverBullFailure>>());
      verify(
        () => status.markBackupStored(RecoverBullNetwork.mainnet),
      ).called(1);
    },
  );

  test('cancel before a provider save prevents external writes', () async {
    canceled = true;
    expect(
      await workflow().execute(
        pending: pending,
        provider: VaultProvider.customLocation,
        cancelled: () => canceled,
      ),
      isA<Err<PendingVaultBackup, RecoverBullFailure>>(),
    );
    verifyNever(() => files.execute(vault: pending.vault));
    verifyNever(() => status.markBackupStored(RecoverBullNetwork.mainnet));
  });

  test(
    'known disposal cannot reject a provider save already completed',
    () async {
      when(() => files.execute(vault: pending.vault)).thenAnswer((_) async {
        canceled = true;
        disposed = true;
        return const Ok(null);
      });
      expect(
        await workflow().execute(
          pending: pending,
          provider: VaultProvider.customLocation,
          cancelled: () => canceled,
        ),
        isA<Ok<PendingVaultBackup, RecoverBullFailure>>(),
      );
      verifyNever(() => status.markBackupStored(RecoverBullNetwork.mainnet));
    },
  );

  test(
    'a failed provider save never marks the backup stored after cancellation',
    () async {
      when(() => files.execute(vault: pending.vault)).thenAnswer((_) async {
        canceled = true;
        return const Err(RecoverBullUnexpectedFailure());
      });
      expect(
        await workflow().execute(
          pending: pending,
          provider: VaultProvider.customLocation,
          cancelled: () => canceled,
        ),
        isA<Err<PendingVaultBackup, RecoverBullFailure>>(),
      );
      verifyNever(() => status.markBackupStored(RecoverBullNetwork.mainnet));
    },
  );

  test(
    'programmer Errors in an active status writer still propagate',
    () async {
      when(() => files.execute(vault: pending.vault)).thenAnswer((_) async {
        canceled = true;
        return const Ok(null);
      });
      when(
        () => status.markBackupStored(RecoverBullNetwork.mainnet),
      ).thenThrow(StateError('programmer fixture'));
      await expectLater(
        workflow().execute(
          pending: pending,
          provider: VaultProvider.customLocation,
          cancelled: () => canceled,
        ),
        throwsStateError,
      );
    },
  );
}
