import 'package:bull_recoverbull/src/data/recoverbull_attempt_monitoring_store.dart';
import 'package:bull_recoverbull/src/data/recoverbull_attempt_monitoring_repository_impl.dart';
import 'package:bull_recoverbull/src/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import '../support/log_sink.dart';

void main() {
  late RecoverBullDatabase database;
  late RecoverBullAttemptMonitoringStore store;
  late RecoverBullAttemptMonitoringRepositoryImpl repository;
  late TestLogSink log;

  setUp(() async {
    database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    await database.ensureState();
    store = RecoverBullAttemptMonitoringStore(database);
    log = TestLogSink.recording();
    repository = RecoverBullAttemptMonitoringRepositoryImpl(store, log: log);
  });
  tearDown(() => database.close());

  test(
    'database exceptions become failures without leaking SQL or identifiers',
    () async {
      await database.customStatement('DROP TABLE recoverbull_state');
      final result = await repository.state();
      expect((result as Err).failure, isA<RecoverBullUnexpectedFailure>());
      expect(
        log.entries.single.message,
        startsWith('recoverbull.attempts.storage.state.failed error_type='),
      );
      expect(log.entries.single.error, isNull);
      expect(log.entries.single.message, isNot(contains('DROP TABLE')));
    },
  );

  test('adapter preserves stale snapshot rejection after reset', () async {
    await store.registerBackup([1, 2, 3]);
    final token =
        (await repository.captureToken()
                as Ok<
                  RecoverBullAttemptMonitoringSnapshotToken,
                  RecoverBullFailure
                >)
            .value;
    expect(await repository.reset(), isA<Ok<Null, RecoverBullFailure>>());
    final result = await repository.applySnapshot(
      RecoverBullAttemptsSnapshot(
        collectionStartedAt: DateTime.utc(2026),
        totalAttempts: {
          store.digestFor([1, 2, 3]): 99,
        },
      ),
      token,
    );
    expect(
      (result
              as Ok<
                RecoverBullAttemptMonitoringApplyResult,
                RecoverBullFailure
              >)
          .value
          .accepted,
      isFalse,
    );
    expect(await store.monitoredBackups(), isEmpty);
  });

  test('invalid programmer inputs remain Errors', () async {
    await expectLater(
      repository.registerBackup([1], observedTotal: -1),
      throwsArgumentError,
    );
    expect(log.entries, isEmpty);
  });
}
