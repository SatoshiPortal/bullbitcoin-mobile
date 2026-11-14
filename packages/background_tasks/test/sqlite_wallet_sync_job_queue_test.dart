import 'dart:convert';
import 'dart:io';

import 'package:background_tasks/background_tasks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:transaction_sync/transaction_sync.dart';

void main() {
  late Directory directory;
  late _FakeClock clock;
  late String path;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('wallet_sync_queue');
    clock = _FakeClock(DateTime.utc(2026, 1, 1));
    path = '${directory.path}/queue.sqlite';
  });

  tearDown(() => directory.delete(recursive: true));

  WalletSyncJobQueueRepository queue({BackgroundTaskLogger? sink}) =>
      switch (SqliteWalletSyncJobQueueRepository.openForeground(
        path,
        clock: clock.call,
        leaseDuration: const Duration(minutes: 10),
        retryBase: const Duration(minutes: 1),
        logSink: sink ?? _Sink(),
      )) {
        Ok(:final value) => value,
        Err(:final failure) => fail('$failure'),
      };

  test(
    'overdue retry runs despite two repeatedly successful wallets',
    () async {
      final current = queue();
      addTearDown(current.close);
      final jobs = List.generate(3, _registration);
      final initial = await current.claim(jobs, chain: WalletSyncChain.bitcoin);
      for (final claim in initial) {
        await current.succeeded(claim);
      }
      final failed = (await current.claim(
        jobs,
        chain: WalletSyncChain.bitcoin,
      )).single;
      expect(failed.key.id, 'wallet-2');
      await current.failed(failed, permanent: false);
      var retried = false;
      for (var run = 0; run < 3; run++) {
        clock.advance(const Duration(hours: 1));
        final claims = await current.claim(
          jobs,
          chain: WalletSyncChain.bitcoin,
        );
        expect(claims.length, lessThanOrEqualTo(2));
        for (final claim in claims) {
          retried |= claim.key == failed.key;
          await current.succeeded(claim);
        }
      }
      expect(retried, isTrue);
    },
  );

  test('rotates five wallets in stable 2, 2, 1 batches after reopen', () async {
    final registrations = List.generate(5, _registration);
    final seen = <String>[];

    for (var run = 0; run < 4; run++) {
      final current = queue();
      final claims = await current.claim(
        registrations,
        chain: WalletSyncChain.bitcoin,
      );
      seen.addAll(claims.map((claim) => claim.key.id));
      for (final claim in claims) {
        expect(await current.succeeded(claim), isTrue);
      }
      await current.close();
      clock.advance(const Duration(microseconds: 1));
    }

    expect(seen, [
      'wallet-0',
      'wallet-1',
      'wallet-2',
      'wallet-3',
      'wallet-4',
      'wallet-0',
      'wallet-1',
    ]);
  });

  test(
    'never-synced wallets precede successful wallets ordered oldest first',
    () async {
      final current = queue();
      final first = (await current.claim([
        _registration(0),
      ], chain: WalletSyncChain.bitcoin)).single;
      expect(await current.succeeded(first), isTrue);
      clock.advance(const Duration(minutes: 1));

      final neverSynced = await current.claim([
        _registration(0),
        _registration(1),
      ], chain: WalletSyncChain.bitcoin);
      expect(neverSynced.map((claim) => claim.key.id), ['wallet-1']);
      expect(await current.succeeded(neverSynced.single), isTrue);
      clock.advance(const Duration(minutes: 1));

      final oldestFirst = await current.claim([
        _registration(0),
        _registration(1),
      ], chain: WalletSyncChain.bitcoin);
      expect(oldestFirst.map((claim) => claim.key.id), [
        'wallet-0',
        'wallet-1',
      ]);
      await current.close();
    },
  );

  test(
    'retry backoff survives reopen without starving an eligible wallet',
    () async {
      var current = queue();
      final successful = (await current.claim([
        _registration(0),
      ], chain: WalletSyncChain.bitcoin)).single;
      expect(await current.succeeded(successful), isTrue);
      clock.advance(const Duration(minutes: 1));

      final newWallet = (await current.claim([
        _registration(0),
        _registration(1),
      ], chain: WalletSyncChain.bitcoin)).single;
      expect(newWallet.key.id, 'wallet-1');
      expect(await current.failed(newWallet, permanent: false), isTrue);
      await current.close();
      current = queue();

      final duringBackoff = await current.claim([
        _registration(0),
        _registration(1),
      ], chain: WalletSyncChain.bitcoin);
      expect(duringBackoff.map((claim) => claim.key.id), ['wallet-0']);
      expect(await current.succeeded(duringBackoff.single), isTrue);
      clock.advance(const Duration(minutes: 1));

      // An attempted wallet no longer keeps the synced ones out of the run,
      // and goes after them: one that keeps failing cannot starve the others.
      final retry = await current.claim([
        _registration(0),
        _registration(1),
      ], chain: WalletSyncChain.bitcoin);
      expect(retry.map((claim) => claim.key.id), ['wallet-0', 'wallet-1']);
      await current.close();
    },
  );

  test('a released claim is claimable again without a penalty', () async {
    final current = queue();
    final claim = (await current.claim([
      _registration(0),
    ], chain: WalletSyncChain.bitcoin)).single;

    expect(await current.released(claim), isTrue);

    // Immediately, without waiting for the lease or a backoff.
    final again = await current.claim([
      _registration(0),
    ], chain: WalletSyncChain.bitcoin);
    expect(again.map((claim) => claim.key.id), ['wallet-0']);
    expect(await current.released(claim), isFalse);
    await current.close();
  });

  test('a wallet whose worker never completes stops starving others', () async {
    final current = queue();
    Future<List<String>> claim() async => (await current.claim([
      _registration(0),
      _registration(1),
    ], chain: WalletSyncChain.bitcoin)).map((claim) => claim.key.id).toList();
    final synced = (await current.claim([
      _registration(0),
    ], chain: WalletSyncChain.bitcoin)).single;
    expect(await current.succeeded(synced), isTrue);
    clock.advance(const Duration(minutes: 1));

    // The never-synced wallet is claimed alone; its worker dies without
    // completing, so only the lease expiry frees it.
    expect(await claim(), ['wallet-1']);
    clock.advance(const Duration(minutes: 11));
    expect(await claim(), ['wallet-0', 'wallet-1']);

    // Every dead claim backs the wallet off further, until it waits longer
    // than a lease and the other wallet runs alone.
    for (var round = 0; round < 3; round++) {
      clock.advance(const Duration(minutes: 11));
      await claim();
    }
    clock.advance(const Duration(minutes: 11));
    expect(await claim(), ['wallet-0']);
    await current.close();
  });

  test(
    'permanent failure remains disabled until its revision changes',
    () async {
      final current = queue();
      final claim = (await current.claim([
        _registration(0),
      ], chain: WalletSyncChain.bitcoin)).single;
      expect(await current.failed(claim, permanent: true), isTrue);

      expect(
        await current.claim([_registration(0)], chain: WalletSyncChain.bitcoin),
        isEmpty,
      );
      final changed = await current.claim([
        _registration(0, revision: 2),
      ], chain: WalletSyncChain.bitcoin);
      expect(changed.map((claim) => claim.key.id), ['wallet-0']);
      await current.close();
    },
  );

  test('generation change re-enables repair failure after reopen', () async {
    var current = queue();
    final claim = (await current.claim([
      _registration(0, revision: 8),
    ], chain: WalletSyncChain.bitcoin)).single;
    await current.failed(claim, permanent: true);
    await current.close();
    current = queue();
    expect(
      await current.claim([
        _registration(0, revision: 8),
      ], chain: WalletSyncChain.bitcoin),
      isEmpty,
    );
    final repaired = await current.claim([
      _registration(0, generation: 2),
    ], chain: WalletSyncChain.bitcoin);
    expect(repaired.single.key.id, 'wallet-0');
    await current.close();
  });

  test(
    'concurrent instances never double-claim and recover expired leases',
    () async {
      final first = queue();
      final second = queue();
      final registration = _registration(0);
      final results = await Future.wait([
        first.claim([registration], chain: WalletSyncChain.bitcoin),
        second.claim([registration], chain: WalletSyncChain.bitcoin),
      ]);
      final claims = results.expand((result) => result).toList();
      expect(claims, hasLength(1));
      expect(
        await second.claim([registration], chain: WalletSyncChain.bitcoin),
        isEmpty,
      );

      clock.advance(const Duration(minutes: 11));
      final replacement = (await second.claim([
        registration,
      ], chain: WalletSyncChain.bitcoin)).single;
      expect(replacement.leaseToken, isNot(claims.single.leaseToken));
      expect(await first.succeeded(claims.single), isFalse);
      expect(await second.succeeded(claims.single), isFalse);
      expect(await second.succeeded(replacement), isTrue);
      await first.close();
      await second.close();
    },
  );

  test(
    'revision changes wait for a live lease before becoming eligible',
    () async {
      final owner = queue();
      final updater = queue();
      final original = (await owner.claim([
        _registration(0),
      ], chain: WalletSyncChain.bitcoin)).single;

      expect(
        await updater.claim([
          _registration(0, revision: 2),
        ], chain: WalletSyncChain.bitcoin),
        isEmpty,
      );
      expect(await owner.renewed(original), isTrue);
      clock.advance(const Duration(minutes: 11));

      final replacement = (await updater.claim([
        _registration(0, revision: 2),
      ], chain: WalletSyncChain.bitcoin)).single;
      expect(replacement.leaseToken, isNot(original.leaseToken));
      expect(await owner.succeeded(original), isFalse);
      expect(await updater.succeeded(replacement), isTrue);
      await owner.close();
      await updater.close();
    },
  );

  test(
    'active deletion waits for lease release and then removes state',
    () async {
      final owner = queue();
      final reconciler = queue();
      final claim = (await owner.claim([
        _registration(0),
      ], chain: WalletSyncChain.bitcoin)).single;

      expect(
        await reconciler.claim(const [], chain: WalletSyncChain.bitcoin),
        isEmpty,
      );
      expect(await owner.succeeded(claim), isTrue);
      final recreated = await reconciler.claim([
        _registration(0),
      ], chain: WalletSyncChain.bitcoin);
      expect(recreated.map((entry) => entry.key.id), ['wallet-0']);
      await owner.close();
      await reconciler.close();
    },
  );

  test(
    'database and logs omit raw wallet identities and lease details',
    () async {
      final messages = <String>[];
      final sink = _Sink(messages);
      final current = queue(sink: sink);
      const walletId = 'never-persist-or-log-this-wallet';
      final claims = await current.claim([
        WalletRevision(
          key: WalletKey(id: walletId, network: BitcoinNetwork.testnet),
          generation: 1,
          revision: 1,
        ),
      ], chain: WalletSyncChain.bitcoin);

      expect(sink.levels, [BackgroundLogLevel.fine]);
      final logs = messages.join('\n');
      expect(logs, contains('chain=bitcoin'));
      expect(logs, contains('eligible=1'));
      expect(logs, isNot(contains(walletId)));
      expect(logs, isNot(contains(claims.single.jobId)));
      expect(logs, isNot(contains(claims.single.leaseToken)));
      await current.close();
      final databaseBytes = utf8.decode(
        await File(path).readAsBytes(),
        allowMalformed: true,
      );
      expect(databaseBytes, isNot(contains(walletId)));
    },
  );

  test('logging failures cannot alter queue behavior', () async {
    final current = queue(sink: _ThrowingSink());
    expect(
      await current.claim([_registration(0)], chain: WalletSyncChain.bitcoin),
      hasLength(1),
    );
    await current.close();
  });

  test(
    'a wallet whose run keeps being stopped does not starve the next',
    () async {
      // The platform stops the run while wallet-0 syncs, every time: its
      // claim is never completed and its lease expires.
      final current = queue();
      final registrations = [_registration(0), _registration(1)];
      final first = await current.claim(
        registrations,
        chain: WalletSyncChain.bitcoin,
        maxJobs: 1,
      );
      expect(first.single.key.id, 'wallet-0');
      clock.advance(const Duration(minutes: 11));

      final next = await current.claim(
        registrations,
        chain: WalletSyncChain.bitcoin,
        maxJobs: 1,
      );
      expect(next.single.key.id, 'wallet-1');
      await current.close();
    },
  );

  test('a claim skips the wallets a run already handled', () async {
    // A wallet completed in this run is due again at once; the run must not
    // sync it twice.
    final current = queue();
    final registrations = [_registration(0)];
    final first = await current.claim(
      registrations,
      chain: WalletSyncChain.bitcoin,
      maxJobs: 1,
    );
    expect(await current.succeeded(first.single), isTrue);

    expect(
      await current.claim(
        registrations,
        chain: WalletSyncChain.bitcoin,
        maxJobs: 1,
        excluding: [first.single.key],
      ),
      isEmpty,
    );
    await current.close();
  });
  test('a storage failure is not reported as a lost claim', () async {
    final current = queue();
    addTearDown(current.close);
    final claim = (await current.claim([
      _registration(0),
    ], chain: WalletSyncChain.bitcoin)).single;
    final database = sqlite3.open(path);
    addTearDown(database.dispose);
    database.execute('DROP TABLE wallet_sync_jobs');

    expect(
      await current.completeSuccess(claim),
      isA<Err<void, BackgroundTasksFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<BackgroundTasksStorageFailure>(),
      ),
    );
  });

  group('openExisting', () {
    Matcher refused(Matcher failure) =>
        isA<Err<SqliteWalletSyncJobQueueRepository, BackgroundTasksFailure>>()
            .having((r) => r.failure, 'failure', failure);

    test('opens the queue the foreground created, with its jobs', () async {
      final created = queue();
      expect(
        await created.claim([_registration(0)], chain: WalletSyncChain.bitcoin),
        hasLength(1),
      );
      await created.close();
      clock.advance(const Duration(minutes: 11));

      final existing = SqliteWalletSyncJobQueueRepository.openExisting(
        path,
        clock: clock.call,
      );
      expect(
        existing,
        isA<Ok<SqliteWalletSyncJobQueueRepository, BackgroundTasksFailure>>(),
      );
      if (existing case Ok(:final value)) {
        addTearDown(value.close);
        // The expired lease of the first run is reclaimed, not recreated.
        final claims = await value.claim([
          _registration(0),
        ], chain: WalletSyncChain.bitcoin);
        expect(claims, hasLength(1));
      }
    });

    test('never creates a missing queue', () {
      expect(
        SqliteWalletSyncJobQueueRepository.openExisting(path),
        refused(isA<BackgroundTasksStoreUnavailableFailure>()),
      );
      expect(File(path).existsSync(), isFalse);
    });

    for (final version in [0, 2]) {
      test('refuses version $version without changing it', () {
        final database = sqlite3.open(path);
        addTearDown(database.dispose);
        database.execute('PRAGMA user_version = $version');
        database.execute('CREATE TABLE unknown (id INTEGER)');

        expect(
          SqliteWalletSyncJobQueueRepository.openExisting(path),
          refused(isA<BackgroundTasksStoreVersionFailure>()),
        );
        expect(
          SqliteWalletSyncJobQueueRepository.openForeground(path),
          refused(isA<BackgroundTasksStoreVersionFailure>()),
        );
        expect(
          database.select('PRAGMA user_version').single['user_version'],
          version,
        );
      });
    }
  });
}

/// Claims unwrapped; completions as true, or false when the claim was lost.
extension on WalletSyncJobQueueRepository {
  Future<List<WalletSyncJobClaim>> claim(
    Iterable<WalletRevision> jobs, {
    required WalletSyncChain chain,
    int maxJobs = 2,
    Iterable<WalletKey> excluding = const [],
  }) async => switch (await reconcileAndClaim(
    jobs,
    chain: chain,
    maxJobs: maxJobs,
    excluding: excluding,
  )) {
    Ok(:final value) => value,
    Err(:final failure) => fail('$failure'),
  };

  Future<bool> succeeded(WalletSyncJobClaim claim) async =>
      _held(await completeSuccess(claim));

  Future<bool> failed(
    WalletSyncJobClaim claim, {
    required bool permanent,
  }) async => _held(await completeFailure(claim, permanent: permanent));

  Future<bool> released(WalletSyncJobClaim claim) async =>
      _held(await release(claim));

  Future<bool> renewed(WalletSyncJobClaim claim) async =>
      _held(await renew(claim));
}

bool _held(Result<void, BackgroundTasksFailure> result) => switch (result) {
  Ok() => true,
  Err(failure: BackgroundTasksClaimLostFailure()) => false,
  Err(:final failure) => fail('$failure'),
};

WalletRevision _registration(
  int index, {
  int revision = 1,
  int generation = 1,
}) => WalletRevision(
  key: WalletKey(id: 'wallet-$index', network: BitcoinNetwork.testnet),
  generation: generation,
  revision: revision,
);

final class _FakeClock {
  DateTime value;

  _FakeClock(this.value);

  DateTime call() => value;

  void advance(Duration duration) => value = value.add(duration);
}

final class _Sink implements BackgroundTaskLogger {
  final levels = <BackgroundLogLevel>[];
  final List<String>? messages;

  _Sink([this.messages]);

  @override
  Future<void> flush() async {}

  @override
  void write(BackgroundLogLevel level, String message) {
    levels.add(level);
    messages?.add(message);
  }
}

final class _ThrowingSink implements BackgroundTaskLogger {
  @override
  Future<void> flush() async {}
  @override
  void write(BackgroundLogLevel level, String message) {
    throw StateError('logger unavailable');
  }
}
