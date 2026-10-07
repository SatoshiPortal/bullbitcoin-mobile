import 'package:bull_recoverbull/src/attempt_monitoring/recoverbull_attempt_monitoring.dart';
import 'package:bull_recoverbull/src/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/public/recoverbull.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const identifier = [0, 1, 2, 3];
  final collection = DateTime.utc(2026, 8, 5);
  final firstWindow = DateTime.utc(2026, 8, 5, 14);
  final secondWindow = DateTime.utc(2026, 8, 5, 15);

  test('a dismissed suspicious alert stays dismissed for its window across '
      'restarts, and a new window raises it again', () async {
    final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.ensureState();
    final store = RecoverBullAttemptMonitoringStore(database);
    await store.registerBackup(identifier);
    final digest = store.digestFor(identifier);
    var snapshot = RecoverBullAttemptsSnapshot(
      collectionStartedAt: collection,
      totalAttempts: {digest: 3},
      windowStartedAt: {digest: firstWindow},
    );
    Future<RecoverBullAttemptsSnapshot?> poll({
      required String? etag,
      required List<String> backupDigests,
    }) async => snapshot;

    final first = await RecoverBullAttemptMonitoring.open(
      store,
      enabled: true,
      poll: poll,
    );
    final raised = await first.checkOnForeground();
    expect(raised.single.kind, RecoverBullAttemptAlertKind.suspiciousActivity);
    await first.acknowledge(raised.single);

    // The app restarts: a new controller over the same database.
    final restarted = await RecoverBullAttemptMonitoring.open(
      store,
      enabled: true,
      poll: poll,
    );
    expect(await restarted.checkOnForeground(), isEmpty);

    snapshot = RecoverBullAttemptsSnapshot(
      collectionStartedAt: collection,
      totalAttempts: {digest: 5},
      windowStartedAt: {digest: secondWindow},
    );
    final again = await restarted.checkOnForeground();
    expect(again.single.kind, RecoverBullAttemptAlertKind.suspiciousActivity);
    expect(again.single.windowStartedAt, secondWindow);
  });
}
