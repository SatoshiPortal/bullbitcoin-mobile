import 'dart:io';

import 'package:bull_recoverbull/src/data/attempt_monitoring_repository_impl.dart';
import 'package:bull_recoverbull/src/data/backup_metadata_repository_impl.dart';
import 'package:bull_recoverbull/src/data/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/data/recoverbull_storage_failure.dart';
import 'package:bull_recoverbull/src/domain/entities/backup_monitoring.dart';
import 'package:bull_recoverbull/src/domain/entities/backup_settings.dart';
import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/vault_key_fetch.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/repositories/attempt_monitoring_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/key_server_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/fetch_vault_key_usecase.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  final settings = BackupSettings(
    server: Uri.parse('http://example.onion'),
    permissionGranted: true,
    monitoringEnabled: true,
    generation: 0,
  );
  final vault = EncryptedVault(
    id: '11' * 32,
    salt: '22' * 16,
    ciphertext: List.filled(64, 0),
    createdAt: DateTime.utc(2026),
  );

  for (final failure in [
    const RecoverBullStorageFullFailure(),
    const RecoverBullStorageDamagedFailure(),
    const RecoverBullJournalFailure(),
  ]) {
    for (final trash in [false, true]) {
      test(
        'journal ${failure.runtimeType} blocks ${trash ? 'trash' : 'fetch'}',
        () async {
          final server = _Server();
          final usecase = FetchVaultKeyUsecase(_FailedJournal(failure));
          final result = await usecase.execute(
            settings: settings,
            server: server,
            vault: vault,
            password: 'test password',
            trash: trash,
          );
          expect(
            result,
            isA<Err<VaultKeyFetch, RecoverBullFailure>>().having(
              (result) => result.failure,
              'failure',
              same(failure),
            ),
          );
          expect(server.calls, 0);
        },
      );
    }
  }

  test('SQLite primary and extended codes map without exception text', () {
    expect(
      recoverBullStorageFailure(
        SqliteException(extendedResultCode: 13, message: 'private'),
      ),
      isA<RecoverBullStorageFullFailure>(),
    );
    expect(
      recoverBullStorageFailure(
        const FileSystemException('private', '', OSError('private', 28)),
      ),
      isA<RecoverBullStorageFullFailure>(),
    );
    for (final code in [11, 26, 267]) {
      expect(
        recoverBullStorageFailure(
          SqliteException(extendedResultCode: code, message: 'private'),
        ),
        isA<RecoverBullStorageDamagedFailure>(),
      );
    }
    expect(
      recoverBullStorageFailure(
        SqliteException(extendedResultCode: 10, message: 'private'),
      ),
      isA<RecoverBullJournalFailure>(),
    );
  });

  test(
    'real SQLite FULL rolls back the marker and makes no network call',
    () async {
      final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await database.forceOpen();
      final metadata = BackupMetadataRepositoryImpl(database);
      var current = _ok(await metadata.settings());
      _ok(await metadata.acceptServer(current.server));
      current = _ok(await metadata.settings());
      await database.customStatement('CREATE TABLE fill_disk (payload BLOB)');
      await database.customStatement(
        'CREATE TRIGGER require_space BEFORE INSERT ON recoverbull_own_operations BEGIN INSERT INTO fill_disk VALUES (zeroblob(1048576)); END',
      );
      await database.customStatement('PRAGMA max_page_count = 32');
      final repository = AttemptMonitoringRepositoryImpl(
        database,
        durable: true,
      );
      final server = _Server();
      final result = await FetchVaultKeyUsecase(repository).execute(
        settings: current,
        server: server,
        vault: vault,
        password: 'test password',
      );
      expect(
        result,
        isA<Err<VaultKeyFetch, RecoverBullFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<RecoverBullStorageFullFailure>(),
        ),
      );
      expect(server.calls, 0);
      expect(
        await database.select(database.recoverbullOwnOperations).get(),
        isEmpty,
      );
    },
  );

  test(
    'rejected transaction commit does not grant network permission',
    () async {
      var reject = false;
      final database = RecoverBullDatabase.forTesting(
        NativeDatabase.memory(
          setup: (database) => database.commitFilter = () => !reject,
        ),
      );
      addTearDown(database.close);
      await database.forceOpen();
      final metadata = BackupMetadataRepositoryImpl(database);
      var current = _ok(await metadata.settings());
      _ok(await metadata.acceptServer(current.server));
      current = _ok(await metadata.settings());
      reject = true;
      final repository = AttemptMonitoringRepositoryImpl(
        database,
        durable: true,
      );
      final server = _Server();
      final result = await FetchVaultKeyUsecase(repository).execute(
        settings: current,
        server: server,
        vault: vault,
        password: 'test password',
      );
      expect(result, isA<Err<VaultKeyFetch, RecoverBullFailure>>());
      expect(server.calls, 0);
      reject = false;
      expect(
        await database.select(database.recoverbullOwnOperations).get(),
        isEmpty,
      );
    },
  );
}

T _ok<T>(Result<T, RecoverBullFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError(failure.runtimeType.toString()),
};

final class _FailedJournal extends Fake implements AttemptMonitoringRepository {
  final RecoverBullFailure failure;
  _FailedJournal(this.failure);
  @override
  Future<Result<OwnBackupOperation, RecoverBullFailure>> begin(
    BackupSettings settings,
    EncryptedVault vault,
  ) async => Err(failure);
}

final class _Server extends Fake implements KeyServerRepository {
  int calls = 0;
  @override
  Future<Result<VaultKeyFetch, RecoverBullFailure>> fetch(
    EncryptedVault vault,
    String password,
  ) async {
    calls++;
    return const Err(KeyServerFailure(KeyServerFailureKind.credentials));
  }

  @override
  Future<Result<VaultKeyFetch, RecoverBullFailure>> trash(
    EncryptedVault vault,
    String password,
  ) => fetch(vault, password);
}
