import 'dart:async';

import 'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart';
import 'package:bull_recoverbull/src/public/recoverbull.dart';
import 'package:bull_recoverbull/src/attempt_monitoring/recoverbull_attempt_monitoring.dart'
    hide RecoverBullAttemptAlert, RecoverBullAttemptAlertKind;
import 'package:bull_recoverbull/src/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/ui/widgets/attempt_alert_warnings.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Controller implements RecoverBullAttemptMonitoringController {
  final List<RecoverBullAttemptAlert> visible;
  final _updates = StreamController<List<RecoverBullAttemptAlert>>.broadcast();
  _Controller(this.visible);

  @override
  Stream<List<RecoverBullAttemptAlert>> get alerts async* {
    yield List.unmodifiable(visible);
    yield* _updates.stream;
  }

  @override
  bool get enabled => true;
  @override
  Future<List<RecoverBullAttemptAlert>> check() async => visible;
  @override
  Future<List<RecoverBullAttemptAlert>> checkOnColdLaunch() async => visible;
  @override
  Future<void> setEnabled(bool enabled) async {}
  @override
  Future<void> acknowledge(RecoverBullAttemptAlert alert) async {
    visible.remove(alert);
    _updates.add(List.unmodifiable(visible));
  }

  Future<void> dispose() => _updates.close();
}

void main() {
  testWidgets(
    'cold-launch alert is visible to a later subscriber and disappears when acknowledged',
    (tester) async {
      final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
      await database.ensureState();
      final store = RecoverBullAttemptMonitoringStore(database);
      final id = List<int>.generate(16, (i) => i);
      await store.registerBackup(id);
      final digest = (await store.monitoredBackups()).single.digest;
      final monitoring = RecoverBullAttemptMonitoring(
        store,
        enabled: true,
        poll: ({required etag, required backupDigests}) async =>
            RecoverBullAttemptsSnapshot(
              collectionStartedAt: DateTime.utc(2026, 8, 5, 14),
              totalAttempts: {digest: 1},
            ),
      );

      await monitoring.checkOnColdLaunch();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates:
              RecoverBullLocalizations.localizationsDelegates,
          home: RecoverBullAttemptAlertWarnings(controller: monitoring),
        ),
      );
      await tester.pump();
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.text('RecoverBull security notice'), findsNothing);

      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(find.byType(ListTile), findsNothing);
      await database.close();
    },
  );

  testWidgets('repeated service pressure keeps one visible advisory', (
    tester,
  ) async {
    final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    await database.ensureState();
    final store = RecoverBullAttemptMonitoringStore(database);
    await store.registerBackup(List<int>.generate(16, (i) => i));
    final monitoring = RecoverBullAttemptMonitoring(
      store,
      enabled: true,
      poll: ({required etag, required backupDigests}) async =>
          RecoverBullAttemptsSnapshot(
            collectionStartedAt: DateTime.utc(2026, 8, 5, 14),
            totalAttempts: const {},
            serviceBusy: true,
          ),
    );

    await monitoring.check();
    await monitoring.check();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        home: RecoverBullAttemptAlertWarnings(controller: monitoring),
      ),
    );
    await tester.pump();

    expect(find.byType(ListTile), findsOneWidget);
    await database.close();
  });

  testWidgets('renders kind-specific copy and dismisses every alert', (
    tester,
  ) async {
    final kinds = RecoverBullAttemptAlertKind.values;
    for (final kind in kinds) {
      final controller = _Controller([RecoverBullAttemptAlertState(kind)]);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates:
              RecoverBullLocalizations.localizationsDelegates,
          home: RecoverBullAttemptAlertWarnings(controller: controller),
        ),
      );
      await tester.pump();
      final l10n = RecoverBullLocalizations.of(
        tester.element(find.byType(RecoverBullAttemptAlertWarnings)),
      );
      final expected = switch (kind) {
        RecoverBullAttemptAlertKind.suspiciousActivity =>
          l10n.recoverbullAttemptMonitoringSuspiciousActivityTitle,
        RecoverBullAttemptAlertKind.targetedLockout =>
          l10n.recoverbullAttemptMonitoringLockoutTitle,
        RecoverBullAttemptAlertKind.servicePressure =>
          l10n.recoverbullAttemptMonitoringServicePressure,
        RecoverBullAttemptAlertKind.unavailable =>
          l10n.recoverbullAttemptMonitoringUnavailableUnknownDuration,
        RecoverBullAttemptAlertKind.countersWiped =>
          l10n.recoverbullAttemptMonitoringCountersWiped,
      };
      expect(find.text(expected), findsOneWidget);
      if (kind != RecoverBullAttemptAlertKind.suspiciousActivity) {
        expect(
          find.text(l10n.recoverbullAttemptMonitoringSuspiciousActivityTitle),
          findsNothing,
        );
      }
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(find.byType(ListTile), findsNothing);
      await controller.dispose();
    }
  });
}
