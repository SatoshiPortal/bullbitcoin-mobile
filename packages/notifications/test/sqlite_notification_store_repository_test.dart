import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/src/data/sqlite_notification_store_repository.dart';
import 'package:notifications/src/domain/local_notification.dart';
import 'package:notifications/src/domain/notifications_failure.dart';
import 'package:notifications/src/domain/observation.dart';
import 'package:notifications/src/domain/repositories/notification_store_repository.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

LocalNotification aggregate(List<String> ids) => LocalNotification(
  eventId: 'aggregate-${ids.join(',')}',
  title: 'Payment received',
  body: '${ids.length}',
  createdAt: DateTime.utc(2026, 11, 14),
);

T ok<T>(Result<T, NotificationsFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('Unexpected $failure'),
};

void main() {
  late Directory directory;
  late String path;
  late SqliteNotificationStoreRepository store;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('notification_store_');
    path = '${directory.path}/notifications.sqlite';
    store = ok(SqliteNotificationStoreRepository.openForeground(path));
  });

  tearDown(() async {
    await store.close();
    directory.deleteSync(recursive: true);
  });

  Future<BackgroundObservation> background(
    String topic,
    List<String> ids,
  ) async =>
      ok(await store.recordBackground(Observation(topic, ids), aggregate));

  test('an empty wallet seen in the foreground is a baseline', () async {
    expect(
      await background('wallet', ['first']),
      BackgroundObservation.topicNotInitialized,
    );
    expect(ok(await store.claimNext()), isNull);

    ok(await store.recordForeground(Observation('wallet', [])));

    // The background never took a baseline: its first payment is new.
    expect(
      await background('wallet', ['first']),
      BackgroundObservation.enqueued,
    );
    final claim = ok(await store.claimNext());
    expect(claim?.notification.eventId, 'aggregate-first');
  });

  test('history seen in the foreground is never announced', () async {
    ok(await store.recordForeground(Observation('wallet', ['old'])));
    ok(await store.recordForeground(Observation('wallet', ['old', 'seen'])));

    expect(
      await background('wallet', ['old', 'seen']),
      BackgroundObservation.nothingNew,
    );
    expect(ok(await store.claimNext()), isNull);
  });

  test('only events stored for the first time form the aggregate', () async {
    ok(await store.recordForeground(Observation('wallet', ['old'])));
    final ids = [for (var i = 0; i < 450; i++) 'tx$i'];

    expect(
      await background('wallet', ['old', ...ids]),
      BackgroundObservation.enqueued,
    );
    // A replay of the same history adds nothing.
    expect(
      await background('wallet', ['old', ...ids]),
      BackgroundObservation.nothingNew,
    );
    expect(
      await background('other', ids),
      BackgroundObservation.topicNotInitialized,
    );

    final claim = ok(await store.claimNext());
    expect(claim?.notification.body, '450');
    expect(claim?.notification.eventId, 'aggregate-${ids.join(',')}');
    if (claim != null) ok(await store.settle(claim));
    expect(ok(await store.claimNext()), isNull);
  });

  test('a failed aggregate leaves no observed event behind', () async {
    ok(await store.recordForeground(Observation('wallet', [])));

    await expectLater(
      store.recordBackground(
        Observation('wallet', ['new']),
        (_) => throw StateError('programming error'),
      ),
      throwsStateError,
    );

    // Rolled back: the event is still new and still announced.
    expect(await background('wallet', ['new']), BackgroundObservation.enqueued);
  });

  test(
    'platform IDs are never reused and their exhaustion is refused',
    () async {
      ok(await store.recordForeground(Observation('wallet', [])));
      await background('wallet', ['a']);
      final first = ok(await store.claimNext());
      if (first == null) return fail('Nothing claimed');
      ok(await store.settle(first));
      await background('wallet', ['b']);
      final second = ok(await store.claimNext());
      expect(second?.platformId, first.platformId + 1);

      final database = sqlite3.open(path);
      addTearDown(database.dispose);
      database.execute('UPDATE platform_ids SET next_id = ?', [
        SqliteNotificationStoreRepository.maxPlatformId + 1,
      ]);
      final refused = await store.recordBackground(
        Observation('wallet', ['c']),
        aggregate,
      );
      expect(
        refused,
        isA<Err<BackgroundObservation, NotificationsFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<NotificationsPlatformIdsExhaustedFailure>(),
        ),
      );
      // Refused atomically: the event stays new.
      database.execute('UPDATE platform_ids SET next_id = 7');
      expect(await background('wallet', ['c']), BackgroundObservation.enqueued);
    },
  );

  test(
    'a claim taken over after its lease cannot be settled by its first owner',
    () async {
      ok(await store.recordForeground(Observation('wallet', [])));
      await background('wallet', ['a']);
      final start = DateTime.utc(2026, 11, 14, 12);
      final stale = ok(await store.claimNext(now: start));
      if (stale == null) return fail('Nothing claimed');
      expect(ok(await store.claimNext(now: start)), isNull);

      final current = ok(
        await store.claimNext(now: start.add(const Duration(minutes: 6))),
      );
      if (current == null) return fail('Lease not reclaimed');
      expect(current.platformId, stale.platformId);

      expect(
        await store.settle(stale),
        isA<Err<void, NotificationsFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<NotificationsClaimLostFailure>(),
        ),
      );
      expect(
        await store.release(stale),
        isA<Err<void, NotificationsFailure>>(),
      );
      expect(
        await store.settle(current),
        isA<Ok<void, NotificationsFailure>>(),
      );
    },
  );

  test('two connections never claim the same aggregate', () async {
    ok(await store.recordForeground(Observation('wallet', [])));
    await background('wallet', ['a']);
    final other = ok(SqliteNotificationStoreRepository.openForeground(path));
    addTearDown(other.close);
    final now = DateTime.utc(2026, 11, 14, 12);

    expect(ok(await store.claimNext(now: now)), isNotNull);
    expect(ok(await other.claimNext(now: now)), isNull);
  });

  group('openExisting', () {
    Matcher refused(Matcher failure) =>
        isA<Err<SqliteNotificationStoreRepository, NotificationsFailure>>()
            .having((r) => r.failure, 'failure', failure);

    test('opens the store the foreground created and keeps its data', () async {
      ok(await store.recordForeground(Observation('wallet', [])));
      final existing = ok(SqliteNotificationStoreRepository.openExisting(path));
      addTearDown(existing.close);
      final observed = await existing.recordBackground(
        Observation('wallet', ['new']),
        aggregate,
      );
      expect(observed, isA<Ok<BackgroundObservation, NotificationsFailure>>());
    });

    test('never creates a missing store', () {
      final missing = '${directory.path}/missing.sqlite';
      expect(
        SqliteNotificationStoreRepository.openExisting(missing),
        refused(isA<NotificationsStoreUnavailableFailure>()),
      );
      expect(File(missing).existsSync(), isFalse);
    });

    for (final version in [0, 2]) {
      test('refuses version $version without changing it', () {
        final other = '${directory.path}/v$version.sqlite';
        final database = sqlite3.open(other);
        addTearDown(database.dispose);
        database.execute('PRAGMA user_version = $version');
        database.execute('CREATE TABLE unknown (id INTEGER)');

        expect(
          SqliteNotificationStoreRepository.openExisting(other),
          refused(isA<NotificationsStoreVersionFailure>()),
        );
        // The foreground refuses it as well instead of rewriting it.
        expect(
          SqliteNotificationStoreRepository.openForeground(other),
          refused(isA<NotificationsStoreVersionFailure>()),
        );
        expect(
          database.select('PRAGMA user_version').single['user_version'],
          version,
        );
      });
    }
  });
}
