import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bull_recoverbull/src/attempt_monitoring/recoverbull_attempt_monitoring.dart';
import 'package:bull_recoverbull/src/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/domain/entities/attempt_alert.dart';
import 'package:bull_recoverbull/src/public/recoverbull.dart';

void main() {
  test(
    'delivers a pre-subscription alert once to the next subscriber',
    () async {
      final harness = await _Harness.create(
        poll: ({required etag, required backupDigests}) async =>
            RecoverBullAttemptsSnapshot(
              collectionStartedAt: DateTime.utc(2026, 8, 5, 14),
              totalAttempts: {_bytesFromHex(backupDigests.single): 1},
            ),
      );
      addTearDown(harness.close);

      await harness.monitoring.check();

      final first = await harness.monitoring.alerts.first;
      expect(first, hasLength(1));
      expect(first.single.kind, RecoverBullAttemptAlertKind.suspiciousActivity);

      await harness.monitoring.acknowledge(first.single);
      expect(await harness.monitoring.alerts.first, isEmpty);
    },
  );

  test('keeps repeated service pressure as one visible alert', () async {
    final harness = await _Harness.create(
      pollResult: RecoverBullAttemptsSnapshot(
        collectionStartedAt: DateTime.utc(2026, 8, 5, 14),
        totalAttempts: {},
        serviceBusy: true,
      ),
    );
    addTearDown(harness.close);

    await harness.monitoring.check();
    await harness.monitoring.check();

    expect(await harness.monitoring.alerts.first, hasLength(1));
    expect(
      (await harness.monitoring.alerts.first).single.kind,
      RecoverBullAttemptAlertKind.servicePressure,
    );
  });

  test(
    'acknowledged identity stays hidden on identical foreground snapshot',
    () async {
      final harness = await _Harness.create(
        poll: ({required etag, required backupDigests}) async =>
            RecoverBullAttemptsSnapshot(
              collectionStartedAt: DateTime.utc(2026, 8, 5, 14),
              totalAttempts: {_bytesFromHex(backupDigests.single): 1},
            ),
      );
      addTearDown(harness.close);

      final firstCheck = await harness.monitoring.check();
      expect(firstCheck, hasLength(1));
      final events = <List<RecoverBullAttemptAlert>>[];
      final subscription = harness.monitoring.alerts.listen(events.add);
      await harness.monitoring.acknowledge(firstCheck.single);

      expect(await harness.monitoring.checkOnForeground(), isEmpty);
      expect(await harness.monitoring.alerts.first, isEmpty);
      expect(events.last, isEmpty);
      await subscription.cancel();
    },
  );

  test('new alert identity remains eligible after dismissal', () async {
    var collectionStartedAt = DateTime.utc(2026, 8, 5, 14);
    var total = 1;
    final harness = await _Harness.create(
      poll: ({required etag, required backupDigests}) async =>
          RecoverBullAttemptsSnapshot(
            collectionStartedAt: collectionStartedAt,
            totalAttempts: {_bytesFromHex(backupDigests.single): total},
          ),
    );
    addTearDown(harness.close);

    final first = (await harness.monitoring.check()).single;
    await harness.monitoring.acknowledge(first);

    // A new collection rebaselines silently instead of raising an alarm.
    collectionStartedAt = DateTime.utc(2026, 8, 5, 15);
    expect(await harness.monitoring.checkOnForeground(), isEmpty);

    // A later increase within that collection is a distinct identity that the
    // earlier acknowledgement must not suppress.
    total = 2;
    final visible = await harness.monitoring.checkOnForeground();
    expect(visible, hasLength(1));
    expect(visible.single.correlationId, first.correlationId);
    expect(visible.single.identity, isNot(first.identity));
    expect(await harness.monitoring.alerts.first, hasLength(1));
  });

  test(
    'new suspicious identity with the same correlation is visible',
    () async {
      final harness = await _Harness.create(pollResult: _Harness.emptySnapshot);
      addTearDown(harness.close);

      final first = RecoverBullAttemptAlert.suspiciousActivity(
        backupReference: 'deadbeef',
        correlationId: 'deadbeef00000001',
        observedTotal: 2,
        expectedTotal: 1,
        windowStartedAt: DateTime.utc(2026, 8, 5, 14),
      );
      await harness.monitoring.acknowledge(first);
      harness.monitoring.publish(
        SuspiciousActivityAlert(
          backupIdHash: 'deadbeef00000001',
          observedTotal: 3,
          expectedTotal: 1,
          windowStartedAt: DateTime.utc(2026, 8, 5, 15),
        ),
      );

      final visible = await harness.monitoring.alerts.first;
      expect(visible, hasLength(1));
      expect(visible.single.correlationId, first.correlationId);
      expect(visible.single.identity, isNot(first.identity));
    },
  );

  test(
    'direct publication stays hidden after its identity is acknowledged',
    () async {
      late String digest;
      final harness = await _Harness.create(
        poll: ({required etag, required backupDigests}) async => () {
          digest = backupDigests.single;
          return RecoverBullAttemptsSnapshot(
            collectionStartedAt: DateTime.utc(2026, 8, 5, 14),
            totalAttempts: {_bytesFromHex(digest): 1},
          );
        }(),
      );
      addTearDown(harness.close);

      final alert = (await harness.monitoring.check()).single;
      await harness.monitoring.acknowledge(alert);
      final targeted = TargetedLockoutAlert(backupIdHash: digest);
      final targetedPublic = RecoverBullAttemptAlert.targetedLockout(
        backupReference: digest,
        correlationId: digest,
      );
      await harness.monitoring.acknowledge(targetedPublic);
      harness.monitoring.publish(targeted);

      expect(await harness.monitoring.alerts.first, isEmpty);
    },
  );

  test('coalesces concurrent normal checks into one poll', () async {
    final pollStarted = Completer<void>();
    final releasePoll = Completer<RecoverBullAttemptsSnapshot?>();
    final harness = await _Harness.create(
      poll: ({required etag, required backupDigests}) {
        pollStarted.complete();
        return releasePoll.future;
      },
    );
    addTearDown(harness.close);

    final first = harness.monitoring.check();
    await pollStarted.future;
    final second = harness.monitoring.check();
    releasePoll.complete(_Harness.emptySnapshot);

    await Future.wait([first, second]);
    expect(harness.pollCalls, 1);
  });

  test('coalesces concurrent forced foreground checks into one poll', () async {
    final pollStarted = Completer<void>();
    final releasePoll = Completer<RecoverBullAttemptsSnapshot?>();
    final harness = await _Harness.create(
      poll: ({required etag, required backupDigests}) {
        pollStarted.complete();
        return releasePoll.future;
      },
    );
    addTearDown(harness.close);

    final first = harness.monitoring.checkOnForeground();
    await pollStarted.future;
    final second = harness.monitoring.checkOnForeground();
    releasePoll.complete(_Harness.emptySnapshot);

    await Future.wait([first, second]);
    expect(harness.pollCalls, 1);
    expect(harness.etags, [null]);
  });

  test(
    'waits for a normal check, then coalesces pending forced checks without an ETag',
    () async {
      final normalStarted = Completer<void>();
      final releaseNormal = Completer<RecoverBullAttemptsSnapshot?>();
      final forcedStarted = Completer<void>();
      final releaseForced = Completer<RecoverBullAttemptsSnapshot?>();
      final harness = await _Harness.create(
        poll: ({required etag, required backupDigests}) {
          if (etag == null) {
            forcedStarted.complete();
            return releaseForced.future;
          }
          normalStarted.complete();
          return releaseNormal.future;
        },
        initialEtag: 'cached-etag',
      );
      addTearDown(harness.close);

      final normal = harness.monitoring.check();
      await normalStarted.future;
      final forced = harness.monitoring.checkOnForeground();
      final forcedAgain = harness.monitoring.checkOnForeground();

      expect(harness.pollCalls, 1);
      releaseNormal.complete(_Harness.emptySnapshot);
      await forcedStarted.future;
      expect(harness.pollCalls, 2);
      releaseForced.complete(_Harness.emptySnapshot);

      await Future.wait([normal, forced, forcedAgain]);
      expect(harness.pollCalls, 2);
      expect(harness.etags, ['cached-etag', null]);
    },
  );
}

final class _Harness {
  static final emptySnapshot = RecoverBullAttemptsSnapshot(
    collectionStartedAt: DateTime.utc(2026, 8, 5, 14),
    totalAttempts: {},
  );

  final RecoverBullDatabase database;
  final RecoverBullAttemptMonitoring monitoring;
  final List<String?> etags = [];
  int pollCalls = 0;

  _Harness(this.database, this.monitoring);

  static Future<_Harness> create({
    RecoverBullAttemptsSnapshot? pollResult,
    Future<RecoverBullAttemptsSnapshot?> Function({
      required String? etag,
      required List<String> backupDigests,
    })?
    poll,
    String? initialEtag,
  }) async {
    final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    await database.ensureState();
    final store = RecoverBullAttemptMonitoringStore(database);
    await store.registerBackup(
      List<int>.generate(16, (index) => index),
      origin: MonitoredBackupOrigin.adopted,
      window: 1,
    );
    if (initialEtag != null) {
      await database
          .update(database.recoverbullState)
          .write(RecoverbullStateCompanion(etag: Value(initialEtag)));
    }

    late final _Harness harness;
    Future<RecoverBullAttemptsSnapshot?> callback({
      required String? etag,
      required List<String> backupDigests,
    }) {
      harness.etags.add(etag);
      harness.pollCalls++;
      return poll?.call(etag: etag, backupDigests: backupDigests) ??
          Future.value(pollResult ?? emptySnapshot);
    }

    harness = _Harness(
      database,
      RecoverBullAttemptMonitoring(store, enabled: true, poll: callback),
    );
    return harness;
  }

  Future<void> close() => database.close();
}

List<int> _bytesFromHex(String value) => [
  for (var index = 0; index < value.length; index += 2)
    int.parse(value.substring(index, index + 2), radix: 16),
];
