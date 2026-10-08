import 'package:bull_recoverbull/src/attempt_monitoring/recoverbull_attempt_monitoring.dart';
import 'package:bull_recoverbull/src/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/public/recoverbull.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public monitoring status reports empty and active coverage', () async {
    final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    await database.ensureState();
    final store = RecoverBullAttemptMonitoringStore(database);
    final controller = RecoverBullAttemptMonitoring(store, enabled: true);

    final empty = await controller.status();
    expect(empty.enabled, isTrue);
    expect(empty.monitoredCount, 0);
    expect(empty.isUncovered, isTrue);
    await store.registerBackup(List<int>.generate(16, (index) => index));
    final active = await controller.status();
    expect(active.monitoredCount, 1);
    expect(active.isUncovered, isFalse);
    await database.close();
  });
}
