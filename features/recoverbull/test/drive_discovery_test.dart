import 'dart:async';
import 'package:bull_recoverbull/src/data/attempt_monitoring_repository_impl.dart';
import 'package:bull_recoverbull/src/data/backup_metadata_repository_impl.dart';
import 'package:bull_recoverbull/src/data/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/data/secrets_vault_repository.dart';
import 'package:bull_recoverbull/src/domain/entities/drive_file_metadata.dart';
import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/repositories/google_drive_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/discover_drive_backups_usecase.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show Secrets;

void main() {
  late RecoverBullDatabase database;
  late BackupMetadataRepositoryImpl metadata;
  late AttemptMonitoringRepositoryImpl monitoring;
  late _Drive drive;
  late DiscoverDriveBackupsUsecase discover;

  setUp(() async {
    database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    await database.forceOpen();
    metadata = BackupMetadataRepositoryImpl(database);
    monitoring = AttemptMonitoringRepositoryImpl(database, durable: true);
    final vaults = SecretsVaultRepository(
      Secrets(scratchDirectory: () async => '/unused'),
    );
    final vault = EncryptedVault(
      id: '11' * 32,
      salt: '22' * 16,
      ciphertext: List.filled(64, 0),
      createdAt: DateTime.utc(2026),
    );
    drive = _Drive(vaults.encode(vault));
    discover = DiscoverDriveBackupsUsecase(drive, vaults, metadata, monitoring);
  });
  tearDown(() => database.close());
  Future<void> accept() async {
    final settings = ok(await metadata.settings());
    ok(await metadata.acceptServer(settings.server));
  }

  test('no Drive discovery before consent or after opt out', () async {
    ok(await discover.execute());
    expect(drive.opens, 0);
    await accept();
    ok(await metadata.setMonitoring(false));
    ok(await discover.execute());
    expect(drive.opens, 0);
  });
  test(
    'all valid discovered vaults enroll without certifying a backup',
    () async {
      await accept();
      ok(await discover.execute());
      expect(ok(await monitoring.prepare())?.digests, hasLength(1));
      expect(
        await database.select(database.recoverbullBackupStatus).get(),
        isEmpty,
      );
    },
  );
  test(
    'account change during content fetch fences local registration',
    () async {
      await accept();
      drive.session.pending = Completer<String>();
      final discovery = discover.execute();
      await drive.session.fetching.future;
      drive.session.current = false;
      drive.session.pending?.complete(drive.session.document);
      expect(await discovery, isA<Err<void, RecoverBullFailure>>());
      expect(ok(await monitoring.prepare()), isNull);
    },
  );
  test(
    'server consent change during discovery fences local registration',
    () async {
      await accept();
      drive.session.pending = Completer<String>();
      final discovery = discover.execute();
      await drive.session.fetching.future;
      ok(await metadata.changeServer(Uri.parse('http://other.onion')));
      drive.session.pending?.complete(drive.session.document);
      expect(await discovery, isA<Err<void, RecoverBullFailure>>());
      expect(
        await database.select(database.recoverbullMonitoredVaults).get(),
        isEmpty,
      );
    },
  );
}

T ok<T>(Result<T, RecoverBullFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError(failure.runtimeType.toString()),
};

final class _Drive extends Fake implements GoogleDriveRepository {
  final _Session session;
  int opens = 0;
  _Drive(String content) : session = _Session(content);
  @override
  Future<T> withDiscoverySession<T>(
    Future<T> Function(GoogleDriveDiscoverySession? session) action,
  ) {
    opens++;
    return action(session);
  }
}

final class _Session implements GoogleDriveDiscoverySession {
  final String document;
  bool current = true;
  Completer<String>? pending;
  final fetching = Completer<void>();
  _Session(this.document);
  @override
  String get account => 'test@example.invalid';
  @override
  Future<T> withCurrentAccount<T>(Future<T> Function() action) async {
    if (!current) throw const FormatException('Account changed');
    return action();
  }

  @override
  Future<List<DriveFileMetadata>> fetchAllMetadata() async => [
    DriveFileMetadata(
      id: 'fixture',
      name: 'vault.json',
      createdTime: DateTime.utc(2026),
    ),
  ];
  @override
  Future<String> fetchRawFile(String fileId) async {
    fetching.complete();
    return pending?.future ?? document;
  }
}
