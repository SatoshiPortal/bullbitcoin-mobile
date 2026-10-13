import 'package:bull_recoverbull/src/attempt_monitoring/recoverbull_attempt_monitoring.dart';
import 'package:bull_recoverbull/src/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/public/recoverbull.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/monitoring_repository.dart';

void main() {
  test(
    'unsupported attempts is an advisory capability and success clears it',
    () async {
      final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await database.ensureState();
      final store = RecoverBullAttemptMonitoringStore(database);
      await store.registerBackup([1, 2, 3]);
      final controller = RecoverBullAttemptMonitoring(
        monitoringRepository(store),
        enabled: true,
        poll: ({required etag, required backupDigests}) async =>
            RecoverBullAttemptsSnapshot(
              collectionStartedAt: DateTime.now().toUtc(),
              totalAttempts: const {},
              serverUnsupported: true,
            ),
      );
      expect(await controller.check(), isEmpty);
      expect((await controller.status()).serverUnsupported, isTrue);
      expect((await store.state()).consecutiveFailures, 0);
      expect((await controller.status()).enabled, isTrue);
      // An accepted later server response forgets the unsupported capability.
      await store.applySnapshot(
        RecoverBullAttemptsSnapshot(
          collectionStartedAt: DateTime.now().toUtc(),
          totalAttempts: const {},
        ),
      );
      expect((await controller.status()).serverUnsupported, isFalse);
    },
  );
}
