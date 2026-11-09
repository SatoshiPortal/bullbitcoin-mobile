import 'dart:io';

import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/data/backup_metadata_repository_impl.dart';
import 'package:bull_recoverbull/src/data/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/data/database/recoverbull_storage.dart';
import 'package:bull_recoverbull/src/domain/entities/backup_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart' show NativeDatabase;
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory directory;
  late String path;
  late RecoverBullStorage owner;
  final first = Uri.parse('http://first.onion');
  final second = Uri.parse('http://second.onion');
  final context = VaultContext(
    fingerprint: Fingerprint('73c5da0a'),
    network: BitcoinNetwork.mainnet,
  );
  final vault = EncryptedVault(
    id: '11' * 32,
    salt: '22' * 16,
    ciphertext: List.filled(64, 0),
    createdAt: DateTime.utc(2026),
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('recoverbull-storage-');
    path = '${directory.path}/recoverbull.sqlite';
    owner = RecoverBullStorage(path);
  });
  tearDown(() async {
    await owner.dispose();
    await directory.delete(recursive: true);
  });

  test('concurrent opens share one connection and survive reopen', () async {
    final connections = await Future.wait([owner.open(), owner.open()]);
    expect(identical(connections[0], connections[1]), isTrue);
    expect(connections.first.schemaVersion, RecoverBullDatabase.schema);
    final repository = BackupMetadataRepositoryImpl(connections.first);
    _ok(await repository.markVerified(context, vault));
    await owner.dispose();
    owner = RecoverBullStorage(path);
    final reopened = BackupMetadataRepositoryImpl(await owner.open());
    expect(_ok(await reopened.status(context)).isVerified, isTrue);
  });

  test('legacy settings import once and cannot resurrect an old URL', () async {
    final repository = BackupMetadataRepositoryImpl(await owner.open());
    final legacy = LegacyBackupSettings(server: first, permissionGranted: true);
    _ok(await repository.importLegacy(legacy));
    expect(_ok(await repository.settings()).permissionGranted, isTrue);
    _ok(await repository.changeServer(second));
    _ok(await repository.importLegacy(legacy));
    final current = _ok(await repository.settings());
    expect(current.server, second);
    expect(current.permissionGranted, isFalse);
    expect(current.monitoringEnabled, isTrue);
    expect(
      await repository.acceptServer(first),
      isA<Err<void, RecoverBullFailure>>(),
    );
    _ok(await repository.acceptServer(second));
    expect(_ok(await repository.settings()).permissionGranted, isTrue);
  });

  test('user choice wins when the legacy read arrives late', () async {
    final repository = BackupMetadataRepositoryImpl(await owner.open());
    _ok(await repository.setMonitoring(false));
    _ok(
      await repository.importLegacy(
        LegacyBackupSettings(server: first, permissionGranted: true),
      ),
    );
    final current = _ok(await repository.settings());
    expect(current.monitoringEnabled, isFalse);
    expect(current.permissionGranted, isFalse);
    expect(current.server, isNot(first));
  });

  test(
    'creation never certifies and verification belongs to its wallet',
    () async {
      final repository = BackupMetadataRepositoryImpl(await owner.open());
      expect(_ok(await repository.status(context)).isVerified, isFalse);
      _ok(await repository.markStored(context, vault));
      expect(_ok(await repository.status(context)).isVerified, isFalse);
      _ok(await repository.markVerified(context, vault));
      expect(_ok(await repository.status(context)).isVerified, isTrue);
      for (final other in [
        VaultContext(
          fingerprint: context.fingerprint,
          network: BitcoinNetwork.testnet,
        ),
        VaultContext(
          fingerprint: Fingerprint('ffffffff'),
          network: context.network,
        ),
      ]) {
        expect(_ok(await repository.status(other)).isVerified, isFalse);
      }
      _ok(await repository.setMonitoring(false));
      expect(_ok(await repository.status(context)).isVerified, isTrue);
    },
  );

  test('future schema is refused without changing its bytes', () async {
    final future = sqlite3.open(path);
    future.execute('CREATE TABLE future_data (value TEXT)');
    future.execute("INSERT INTO future_data VALUES ('preserve')");
    future.execute('PRAGMA user_version = 99');
    future.dispose();
    final before = await File(path).readAsBytes();
    await expectLater(owner.open(), throwsA(anything));
    expect(await File(path).readAsBytes(), before);
    expect(directory.listSync().whereType<File>().length, 1);
  });

  test(
    'an interrupted creation rolls back and the next open completes',
    () async {
      final interrupted = RecoverBullDatabase.forTesting(
        NativeDatabase(
          File(path),
          setup: (database) => database.commitFilter = () => false,
        ),
      );
      await expectLater(interrupted.forceOpen(), throwsA(anything));
      await interrupted.close();
      final raw = sqlite3.open(path);
      expect(
        raw.select("SELECT name FROM sqlite_master WHERE type = 'table'"),
        isEmpty,
      );
      expect(raw.select('PRAGMA user_version').single['user_version'], 0);
      raw.dispose();
      final repository = BackupMetadataRepositoryImpl(await owner.open());
      expect(_ok(await repository.settings()).permissionGranted, isFalse);
    },
  );

  test(
    'IO failure preserves the path and allows isolated temporary recovery',
    () async {
      await Directory(path).create();
      await File('$path/keep').writeAsString('preserve');
      await expectLater(owner.open(), throwsA(anything));
      final temporary = await owner.openTemporary();
      final repository = BackupMetadataRepositoryImpl(
        temporary,
        durable: false,
      );
      expect(identical(await owner.open(), temporary), isTrue);
      expect(_ok(await repository.settings()).permissionGranted, isFalse);
      expect(_ok(await repository.settings()).monitoringEnabled, isFalse);
      _ok(await repository.markVerified(context, vault));
      expect(_ok(await repository.status(context)).isVerified, isFalse);
      expect(await File('$path/keep').readAsString(), 'preserve');
    },
  );

  test(
    'corruption remains intact and manual temporary storage is available',
    () async {
      await File(path).writeAsString('not a sqlite database');
      await expectLater(owner.open(), throwsA(anything));
      expect(await File(path).readAsString(), 'not a sqlite database');
      expect(directory.listSync().whereType<File>(), hasLength(1));
      final temporary = await owner.openTemporary();
      final repository = BackupMetadataRepositoryImpl(
        temporary,
        durable: false,
      );
      expect(_ok(await repository.settings()).permissionGranted, isFalse);
    },
  );
}

T _ok<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError(failure.runtimeType.toString()),
};
