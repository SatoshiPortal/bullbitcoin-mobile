import 'dart:io';

import 'package:bull_recoverbull/src/data/attempt_monitoring_repository_impl.dart';
import 'package:bull_recoverbull/src/data/backup_metadata_repository_impl.dart';
import 'package:bull_recoverbull/src/data/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/domain/entities/attempt_observation.dart';
import 'package:bull_recoverbull/src/domain/entities/backup_monitoring.dart';
import 'package:bull_recoverbull/src/domain/entities/backup_settings.dart';
import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  late Directory directory;
  late RecoverBullDatabase database;
  late AttemptMonitoringRepositoryImpl repository;
  late BackupMetadataRepositoryImpl metadata;
  late BackupSettings settings;
  final vault = EncryptedVault(
    id: '11' * 32,
    salt: '22' * 16,
    ciphertext: List.filled(64, 0),
    createdAt: DateTime.utc(2026),
  );
  final digest = sha256.convert(hex.decode(vault.id)).toString();
  final window = DateTime.utc(2026, 11, 9, 12);
  final collection = DateTime.utc(2026, 11, 9);

  Future<void> open() async {
    database = RecoverBullDatabase.open('${directory.path}/rb.sqlite');
    await database.forceOpen();
    repository = AttemptMonitoringRepositoryImpl(database, durable: true);
    metadata = BackupMetadataRepositoryImpl(database);
  }

  Future<void> sample(int requests, {DateTime? at}) async {
    final check = ok(await repository.prepare());
    expect(check, isNotNull);
    if (check == null) return;
    ok(
      await repository.observe(
        check,
        AttemptSnapshot(
          collectionStartedAt: collection,
          entries: {digest: observation(requests, at ?? window)},
        ),
      ),
    );
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('rb-monitor-');
    await open();
    settings = ok(await metadata.settings());
    ok(await metadata.acceptServer(settings.server));
    settings = ok(await metadata.settings());
    ok(await repository.register(settings, vault));
    await sample(10);
  });
  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('overlapping own requests preserve provable external excess', () async {
    final a = ok(await repository.begin(settings, vault));
    final b = ok(await repository.begin(settings, vault));
    ok(await repository.complete(a, observation: observation(12, window)));
    expect(ok(await repository.status()).alerts, isEmpty);
    ok(await repository.complete(b, observation: observation(13, window)));
    expect(
      ok(await repository.status()).alerts.single.kind,
      BackupAlertKind.unexplainedActivity,
    );
    await sample(13);
    expect(ok(await repository.status()).alerts, hasLength(1));
  });

  test(
    'lost response and unchanged poll keep one bounded own credit',
    () async {
      ok(await repository.begin(settings, vault));
      await sample(10); // Server has not counted the request yet.
      await database.close();
      await open(); // Process lost its operation handle.
      await sample(11);
      expect(ok(await repository.status()).alerts, isEmpty);
      expect(ok(await repository.status()).unknown, isTrue);
      await sample(12);
      expect(ok(await repository.status()).alerts, hasLength(1));
      await sample(13);
      expect(ok(await repository.status()).alerts, hasLength(1));
    },
  );

  test(
    'own attempts never alarm and cached samples cannot lower the anchor',
    () async {
      final a = ok(await repository.begin(settings, vault));
      ok(await repository.complete(a, observation: observation(11, window)));
      await sample(10);
      await sample(11);
      expect(ok(await repository.status()).alerts, isEmpty);
      await sample(12);
      expect(ok(await repository.status()).alerts, hasLength(1));
    },
  );

  test(
    'alarm and acknowledgement survive reopen and duplicate samples',
    () async {
      await sample(11);
      final alert = ok(await repository.status()).alerts.single;
      await database.close();
      await open();
      expect(ok(await repository.status()).alerts.single.kind, alert.kind);
      ok(await repository.acknowledge(alert.acknowledgement));
      await database.close();
      await open();
      await sample(11);
      expect(ok(await repository.status()).alerts, isEmpty);
    },
  );

  test(
    'outage and missing entries stay unknown, targeted lockout persists',
    () async {
      final check = ok(await repository.prepare());
      if (check == null) fail('Expected an eligible check');
      ok(await repository.observe(check, null));
      expect(ok(await repository.status()).unknown, isTrue);
      expect(ok(await repository.status()).alerts, isEmpty);
      final operation = ok(await repository.begin(settings, vault));
      ok(await repository.complete(operation, lockout: true));
      await database.close();
      await open();
      expect(
        ok(await repository.status()).alerts.single.kind,
        BackupAlertKind.lockout,
      );
    },
  );

  test('an operation invalidates a poll captured before its marker', () async {
    final check = ok(await repository.prepare());
    if (check == null) fail('Expected an eligible check');
    ok(await repository.begin(settings, vault));
    ok(
      await repository.observe(
        check,
        AttemptSnapshot(
          collectionStartedAt: collection,
          entries: {digest: observation(99, window)},
        ),
      ),
    );
    expect(ok(await repository.status()).alerts, isEmpty);
  });

  test('consent changes fence replies but retain sent markers', () async {
    final operation = ok(await repository.begin(settings, vault));
    ok(await metadata.changeServer(Uri.parse('http://other.onion')));
    ok(
      await repository.complete(
        operation,
        observation: observation(11, window),
      ),
    );
    expect(ok(await repository.prepare()), isNull);
    ok(await metadata.changeServer(settings.server));
    ok(await metadata.acceptServer(settings.server));
    settings = ok(await metadata.settings());
    await sample(11);
    expect(ok(await repository.status()).alerts, isEmpty);
    expect(ok(await repository.status()).unknown, isTrue);
  });

  test(
    'opt out preserves journal and registry without a network check',
    () async {
      ok(await metadata.setMonitoring(false));
      settings = ok(await metadata.settings());
      ok(await repository.begin(settings, vault));
      expect(ok(await repository.prepare()), isNull);
      ok(await metadata.setMonitoring(true));
      settings = ok(await metadata.settings());
      await sample(11);
      expect(ok(await repository.status()).alerts, isEmpty);
    },
  );

  test('rotation with a pending request remains unknown', () async {
    ok(await repository.begin(settings, vault));
    await sample(0, at: window.add(const Duration(hours: 1)));
    await sample(1, at: window.add(const Duration(hours: 1)));
    expect(ok(await repository.status()).alerts, isEmpty);
    expect(ok(await repository.status()).unknown, isTrue);
  });

  test('temporary storage never admits a counted operation', () async {
    final temporary = AttemptMonitoringRepositoryImpl(database, durable: false);
    expect(
      await temporary.begin(settings, vault),
      isA<Err<OwnBackupOperation, RecoverBullFailure>>(),
    );
  });
}

AttemptObservation observation(int requests, DateTime window) =>
    AttemptObservation(
      attempts: requests == 0 ? 0 : 1,
      requests: requests,
      failures: 0,
      windowStartedAt: window,
    );
T ok<T>(Result<T, RecoverBullFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError(failure.runtimeType.toString()),
};
