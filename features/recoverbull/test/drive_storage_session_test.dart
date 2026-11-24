import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:backup_storage/backup_storage.dart';
import 'package:bull_recoverbull/src/data/datasources/google_drive_datasource.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/data/google_drive_repository.dart';
import 'package:bull_recoverbull/src/data/mappers/encrypted_vault_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _Storage storage;
  late GoogleDriveAppDatasource datasource;

  setUp(() {
    storage = _Storage();
    datasource = GoogleDriveAppDatasource(storage: storage);
  });

  tearDown(() => datasource.dispose());

  test('disconnect without a grant completes after a silent probe', () async {
    storage.authorizeNext = () async =>
        const Err(BackupStorageAuthorizationRequiredFailure());

    await datasource.disconnect();

    expect(storage.interactiveRequests, [false]);
  });

  test('disconnect revokes the newly authorized session only', () async {
    final previous = _Session('previous');
    final current = _Session('current');
    storage.authorizeNext = () async => Ok(previous);
    await datasource.connect();
    storage.authorizeNext = () async => Ok(current);

    await datasource.disconnect();

    expect(storage.interactiveRequests, [true, false]);
    expect(previous.disconnects, 0);
    expect(previous.disposed, isTrue);
    expect(current.disconnects, 1);
    expect(current.disposed, isTrue);
  });

  test('a failed disconnect probe never revokes the old session', () async {
    final previous = _Session('previous');
    storage.authorizeNext = () async => Ok(previous);
    await datasource.connect();
    storage.authorizeNext = () async =>
        const Err(BackupStorageUnavailableFailure());

    await expectLater(datasource.disconnect(), throwsA(isA<Exception>()));

    expect(previous.disconnects, 0);
    expect(previous.disposed, isTrue);
  });

  test('an obsolete disconnect probe cannot revoke its session', () async {
    final lateSession = _Session('previous');
    final current = _Session('current');
    final pending = Completer<Result<StorageSession, BackupStorageFailure>>();
    storage.authorizeNext = () => pending.future;
    final disconnect = expectLater(
      datasource.disconnect(),
      throwsA(isA<Exception>()),
    );
    storage.authorizeNext = () async => Ok(current);
    await datasource.connect();
    pending.complete(Ok(lateSession));
    await disconnect;

    expect(lateSession.disconnects, 0);
    expect(lateSession.disposed, isTrue);
    expect(current.disconnects, 0);
    expect(current.disposed, isFalse);
  });

  test(
    'vault round trip preserves format, name and latest-by-creation selection',
    () async {
      final session = _Session('current');
      storage.authorizeNext = () async => Ok(session);
      final repository = GoogleDriveRepositoryImpl(datasource: datasource);
      addTearDown(repository.dispose);
      final vault = EncryptedVault(
        id: 'aa' * 32,
        salt: 'bb' * 16,
        ciphertext: List.filled(64, 0xcc),
        createdAt: DateTime(2026, 11, 20, 12),
      );

      await repository.connect();
      expect(
        await repository.store(vault),
        isA<Ok<Null, RecoverBullFailure>>(),
      );
      expect(session.writes.single.name, '2026-11-20_encrypted_vault.json');
      expect(session.writes.single.mimeType, 'application/json');
      expect(
        utf8.decode(session.writes.single.bytes),
        EncryptedVaultMapper.fromEntity(vault).toFile(),
      );

      session.listNext = (mimeType) async {
        expect(mimeType, 'application/json');
        return Ok([
          StoredObject(
            id: 'older',
            name: 'older.json',
            createdAt: DateTime.utc(2026, 11, 19),
            modifiedAt: DateTime.utc(2026, 11, 21),
            durability: Durability.durable,
          ),
          StoredObject(
            id: 'latest',
            name: session.writes.single.name,
            createdAt: vault.createdAt,
            durability: Durability.durable,
          ),
        ]);
      };
      final latest = await repository.fetchLatestVault();

      expect(latest, isA<Ok<EncryptedVault, RecoverBullFailure>>());
      final restored = (latest as Ok<EncryptedVault, RecoverBullFailure>).value;
      expect(restored.ciphertext, vault.ciphertext);
      expect(session.reads.single, (id: 'latest', maxBytes: 2 * 1024 * 1024));
    },
  );

  test('a listing cannot outlive its discovery callback', () async {
    final session = _Session('current');
    storage.authorizeNext = () async => Ok(session);
    final repository = GoogleDriveRepositoryImpl(datasource: datasource);
    addTearDown(repository.dispose);
    final pendingList =
        Completer<Result<List<StoredObject>, BackupStorageFailure>>();
    final started = Completer<void>();
    session.listNext = (mimeType) {
      expect(mimeType, 'application/json');
      started.complete();
      return pendingList.future;
    };
    late Future<void> rejected;

    await repository.withDiscoverySession((discovery) async {
      if (discovery == null) fail('Expected a discovery session');
      rejected = expectLater(
        discovery.fetchAllMetadata(),
        throwsA(isA<Exception>()),
      );
      await started.future;
    });
    pendingList.complete(const Ok([]));
    await rejected;
  });
}

final class _Storage extends Fake implements BackupStorage {
  final interactiveRequests = <bool>[];
  late Future<Result<StorageSession, BackupStorageFailure>> Function()
  authorizeNext;

  @override
  Future<Result<StorageSession, BackupStorageFailure>> authorize({
    required bool interactive,
  }) {
    interactiveRequests.add(interactive);
    return authorizeNext();
  }
}

final class _Session extends Fake implements StorageSession {
  @override
  final StorageAccount account;
  final writes = <({String name, String mimeType, Uint8List bytes})>[];
  final reads = <({String id, int maxBytes})>[];
  int disconnects = 0;
  bool disposed = false;
  late Future<Result<List<StoredObject>, BackupStorageFailure>> Function(String)
  listNext;

  _Session(String id) : account = StorageAccount(id: id);

  @override
  Future<Result<List<StoredObject>, BackupStorageFailure>> list({
    required String mimeType,
    String? namePrefix,
  }) => listNext(mimeType);

  @override
  Future<Result<StoredObject, BackupStorageFailure>> create({
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    writes.add((name: name, mimeType: mimeType, bytes: bytes));
    return Ok(
      StoredObject(id: 'latest', name: name, durability: Durability.durable),
    );
  }

  @override
  Future<Result<Uint8List, BackupStorageFailure>> read(
    StoredObject object, {
    required int maxBytes,
  }) async {
    reads.add((id: object.id, maxBytes: maxBytes));
    return Ok(writes.single.bytes);
  }

  @override
  Future<Result<void, BackupStorageFailure>> disconnect() async {
    disconnects++;
    return const Ok(null);
  }

  @override
  void dispose() => disposed = true;
}
