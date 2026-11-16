import 'dart:io';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/sqlite_ark_reminder_repository.dart';
import 'package:bull_ark/src/domain/ark_expiry_warning.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import 'ark_operations_test.dart' show account;
import 'ark_expiry_warning_test.dart' show vtxo;
import 'ark_durable_stores_test.dart' show value, Notifications;

ArkExpiryWarning warning({
  required int tip,
  required DateTime at,
  required Map<String, int> live,
  List<ArkMovement> movements = const [],
}) {
  final snapshot = ArkSnapshot(
    account: account(),
    revision: 5,
    observedAt: at,
    tipHeight: tip,
    stale: false,
    vtxoCompleteness: ArkSectionCompleteness.complete,
    vtxos: [for (final entry in live.entries) vtxo(entry.key, entry.value)],
    movements: movements,
    recovery: ArkRecoveryStatus.complete,
  );
  final result = ArkExpiryWarning.fromSnapshot(snapshot);
  if (result == null) throw StateError('Invalid fixture warning');
  return result;
}

void main() {
  late Directory dir;
  late Notifications gateway;
  late SqliteArkReminderRepository store;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('ark-deadlines-');
    gateway = Notifications();
    store = value(
      SqliteArkReminderRepository.open(
        path: '${dir.path}/ledger',
        notifications: gateway,
        title: 'Urgent',
        body: 'Open Ark',
        foreground: true,
        initializeNew: true,
      ),
    );
  });
  tearDown(() async {
    await store.close();
    dir.deleteSync(recursive: true);
  });
  Future<void> apply(ArkExpiryWarning warning, int revision) async {
    expect(
      await store.reconcile(
        account: account(),
        warning: warning,
        authoritativeEmpty: false,
        revision: revision,
        tipHeight: warning.tipHeight,
      ),
      isA<Ok>(),
    );
  }

  final initial = DateTime.utc(2026, 11, 16);
  test(
    'same inputs accelerated height moves alarm earlier into urgency margin',
    () async {
      final first = warning(tip: 100, at: initial, live: {'old': 500});
      await apply(first, 5);
      final advanced = warning(
        tip: 499,
        at: initial.add(const Duration(hours: 1)),
        live: {'old': 500},
      );
      await apply(advanced, 6);
      expect(gateway.scheduled.last.at, advanced.notifyAt);
      expect(
        gateway.scheduled.last.at.isBefore(gateway.scheduled.first.at),
        true,
      );
    },
  );
  test(
    'unrelated set change cannot postpone an old urgent obligation',
    () async {
      final first = warning(
        tip: 100,
        at: initial,
        live: {'urgent': 500, 'other': 1000},
      );
      await apply(first, 5);
      await apply(
        warning(
          tip: 100,
          at: initial.add(const Duration(hours: 6)),
          live: {'urgent': 500, 'new-other': 2000},
        ),
        6,
      );
      expect(gateway.scheduled.last.at, first.notifyAt);
    },
  );
  test(
    'missing old ID without positive retirement proof cannot postpone alarm',
    () async {
      final first = warning(tip: 100, at: initial, live: {'old': 500});
      await apply(first, 5);
      await apply(
        warning(
          tip: 100,
          at: initial.add(const Duration(hours: 6)),
          live: {'replacement': 1500},
        ),
        6,
      );
      expect(gateway.scheduled.last.at, first.notifyAt);
    },
  );
  test(
    'observed successful linked replacement permits later deadline',
    () async {
      await apply(warning(tip: 100, at: initial, live: {'old': 500}), 5);
      final replacement = warning(
        tip: 100,
        at: initial.add(const Duration(hours: 6)),
        live: {'replacement': 1500},
        movements: [
          ArkMovement(
            id: 'renewal',
            kind: ArkMovementKind.renewal,
            status: ArkMovementStatus.successful,
            inputVtxoIds: ['old'],
            outputVtxoIds: ['replacement'],
          ),
        ],
      );
      await apply(replacement, 6);
      expect(gateway.scheduled.last.at, replacement.notifyAt);
    },
  );
  test('retiring a newer urgent input retains the original bound of another live input', () async {
    final original = warning(tip: 100, at: initial, live: {'original': 1000});
    await apply(original, 5);
    await apply(
      warning(
        tip: 100,
        at: initial.add(const Duration(hours: 6)),
        live: {'original': 1000, 'urgent-new': 500},
      ),
      6,
    );
    await apply(
      warning(
        tip: 100,
        at: initial.add(const Duration(hours: 12)),
        live: {'original': 1000, 'renewed-new': 2000},
        movements: [
          ArkMovement(
            id: 'renew-new',
            kind: ArkMovementKind.renewal,
            status: ArkMovementStatus.successful,
            inputVtxoIds: ['urgent-new'],
            outputVtxoIds: ['renewed-new'],
          ),
        ],
      ),
      7,
    );
    expect(gateway.scheduled.last.at, original.notifyAt);
  });
  test(
    'stale replacement evidence admits known expiry without retiring old bound',
    () async {
      final first = warning(tip: 100, at: initial, live: {'old': 500});
      await apply(first, 5);
      final degraded = ArkExpiryWarning.fromSnapshot(
        ArkSnapshot(
          account: account(),
          revision: 6,
          observedAt: initial.add(const Duration(hours: 6)),
          tipHeight: 110,
          stale: true,
          vtxoCompleteness: ArkSectionCompleteness.complete,
          recovery: ArkRecoveryStatus.complete,
          vtxos: [vtxo('replacement', 1500)],
          movements: [
            ArkMovement(
              id: 'renewal',
              kind: ArkMovementKind.renewal,
              status: ArkMovementStatus.successful,
              inputVtxoIds: ['old'],
              outputVtxoIds: ['replacement'],
            ),
          ],
        ),
      );
      if (degraded == null) fail('Known expiry must be admitted');
      expect(degraded.retiredKeys, isEmpty);
      await apply(degraded, 6);
      expect(gateway.scheduled.last.at, first.notifyAt);
    },
  );
  test(
    'malformed persisted bounds refuse reconciliation without platform effect',
    () async {
      final first = warning(tip: 100, at: initial, live: {'old': 500});
      await apply(first, 5);
      final db = sqlite3.open('${dir.path}/ledger');
      db.execute("UPDATE ark_reminders SET deadline_bounds='{}'");
      db.close();
      expect(
        await store.reconcile(
          account: account(),
          warning: first,
          authoritativeEmpty: false,
          revision: 6,
          tipHeight: 100,
        ),
        isA<Err>(),
      );
      expect(gateway.scheduled.length, 1);
    },
  );
  test('unknown replacement state cannot retire the old bound', () async {
    final first = warning(tip: 100, at: initial, live: {'old': 500});
    await apply(first, 5);
    final uncertain = ArkExpiryWarning.fromSnapshot(
      ArkSnapshot(
        account: account(),
        revision: 6,
        observedAt: initial,
        tipHeight: 110,
        stale: false,
        vtxoCompleteness: ArkSectionCompleteness.complete,
        recovery: ArkRecoveryStatus.complete,
        vtxos: [
          ArkVtxo(
            id: 'replacement',
            amount: Sats.fromInt(1000),
            expiryHeight: 1500,
            state: ArkVtxoState.unknown,
          ),
        ],
        movements: [
          ArkMovement(
            id: 'renewal',
            kind: ArkMovementKind.renewal,
            status: ArkMovementStatus.successful,
            inputVtxoIds: ['old'],
            outputVtxoIds: ['replacement'],
          ),
        ],
      ),
    );
    if (uncertain == null) fail('Known expiry remains admissible');
    expect(uncertain.retiredKeys, isEmpty);
    await apply(uncertain, 6);
    expect(gateway.scheduled.last.at, first.notifyAt);
  });
}
