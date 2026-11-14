import 'dart:convert';
import 'dart:io';

import 'package:background_tasks/background_tasks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

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

  SqliteWalletSyncJobQueue queue({BackgroundTaskLogger? sink}) =>
      SqliteWalletSyncJobQueue(
        databasePath: path,
        clock: clock.call,
        leaseDuration: const Duration(minutes: 10),
        retryBase: const Duration(minutes: 1),
        logSink: sink ?? _Sink(),
      );

  test(
    'overdue retry runs despite two repeatedly successful wallets',
    () async {
      final current = queue();
      addTearDown(current.close);
      final jobs = List.generate(3, _registration);
      final initial = await current.reconcileAndClaim(
        jobs,
        chain: WalletSyncChain.bitcoin,
      );
      for (final claim in initial) {
        await current.completeSuccess(claim);
      }
      final failed = (await current.reconcileAndClaim(
        jobs,
        chain: WalletSyncChain.bitcoin,
      )).single;
      expect(failed.key.id, 'wallet-2');
      await current.completeFailure(failed, permanent: false);
      var retried = false;
      for (var run = 0; run < 3; run++) {
        clock.advance(const Duration(hours: 1));
        final claims = await current.reconcileAndClaim(
          jobs,
          chain: WalletSyncChain.bitcoin,
        );
        expect(claims.length, lessThanOrEqualTo(2));
        for (final claim in claims) {
          retried |= claim.key == failed.key;
          await current.completeSuccess(claim);
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
      final claims = await current.reconcileAndClaim(
        registrations,
        chain: WalletSyncChain.bitcoin,
      );
      seen.addAll(claims.map((claim) => claim.key.id));
      for (final claim in claims) {
        expect(await current.completeSuccess(claim), isTrue);
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
      final first = (await current.reconcileAndClaim([
        _registration(0),
      ], chain: WalletSyncChain.bitcoin)).single;
      expect(await current.completeSuccess(first), isTrue);
      clock.advance(const Duration(minutes: 1));

      final neverSynced = await current.reconcileAndClaim([
        _registration(0),
        _registration(1),
      ], chain: WalletSyncChain.bitcoin);
      expect(neverSynced.map((claim) => claim.key.id), ['wallet-1']);
      expect(await current.completeSuccess(neverSynced.single), isTrue);
      clock.advance(const Duration(minutes: 1));

      final oldestFirst = await current.reconcileAndClaim([
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
      final successful = (await current.reconcileAndClaim([
        _registration(0),
      ], chain: WalletSyncChain.bitcoin)).single;
      expect(await current.completeSuccess(successful), isTrue);
      clock.advance(const Duration(minutes: 1));

      final newWallet = (await current.reconcileAndClaim([
        _registration(0),
        _registration(1),
      ], chain: WalletSyncChain.bitcoin)).single;
      expect(newWallet.key.id, 'wallet-1');
      expect(
        await current.completeFailure(newWallet, permanent: false),
        isTrue,
      );
      await current.close();
      current = queue();

      final duringBackoff = await current.reconcileAndClaim([
        _registration(0),
        _registration(1),
      ], chain: WalletSyncChain.bitcoin);
      expect(duringBackoff.map((claim) => claim.key.id), ['wallet-0']);
      expect(await current.completeSuccess(duringBackoff.single), isTrue);
      clock.advance(const Duration(minutes: 1));

      // An attempted wallet no longer keeps the synced ones out of the run,
      // and goes after them: one that keeps failing cannot starve the others.
      final retry = await current.reconcileAndClaim([
        _registration(0),
        _registration(1),
      ], chain: WalletSyncChain.bitcoin);
      expect(retry.map((claim) => claim.key.id), ['wallet-0', 'wallet-1']);
      await current.close();
    },
  );

  test('a released claim is claimable again without a penalty', () async {
    final current = queue();
    final claim = (await current.reconcileAndClaim([
      _registration(0),
    ], chain: WalletSyncChain.bitcoin)).single;

    expect(await current.release(claim), isTrue);

    // Immediately, without waiting for the lease or a backoff.
    final again = await current.reconcileAndClaim([
      _registration(0),
    ], chain: WalletSyncChain.bitcoin);
    expect(again.map((claim) => claim.key.id), ['wallet-0']);
    expect(await current.release(claim), isFalse);
    await current.close();
  });

  test('a wallet whose worker never completes stops starving others', () async {
    final current = queue();
    Future<List<String>> claim() async => (await current.reconcileAndClaim([
      _registration(0),
      _registration(1),
    ], chain: WalletSyncChain.bitcoin)).map((claim) => claim.key.id).toList();
    final synced = (await current.reconcileAndClaim([
      _registration(0),
    ], chain: WalletSyncChain.bitcoin)).single;
    expect(await current.completeSuccess(synced), isTrue);
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
      final claim = (await current.reconcileAndClaim([
        _registration(0),
      ], chain: WalletSyncChain.bitcoin)).single;
      expect(await current.completeFailure(claim, permanent: true), isTrue);

      expect(
        await current.reconcileAndClaim([
          _registration(0),
        ], chain: WalletSyncChain.bitcoin),
        isEmpty,
      );
      final changed = await current.reconcileAndClaim([
        _registration(0, revision: 2),
      ], chain: WalletSyncChain.bitcoin);
      expect(changed.map((claim) => claim.key.id), ['wallet-0']);
      await current.close();
    },
  );

  test('generation change re-enables repair failure after reopen', () async {
    var current = queue();
    final claim = (await current.reconcileAndClaim([
      _registration(0, revision: 8),
    ], chain: WalletSyncChain.bitcoin)).single;
    await current.completeFailure(claim, permanent: true);
    await current.close();
    current = queue();
    expect(
      await current.reconcileAndClaim([
        _registration(0, revision: 8),
      ], chain: WalletSyncChain.bitcoin),
      isEmpty,
    );
    final repaired = await current.reconcileAndClaim([
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
        first.reconcileAndClaim([registration], chain: WalletSyncChain.bitcoin),
        second.reconcileAndClaim([
          registration,
        ], chain: WalletSyncChain.bitcoin),
      ]);
      final claims = results.expand((result) => result).toList();
      expect(claims, hasLength(1));
      expect(
        await second.reconcileAndClaim([
          registration,
        ], chain: WalletSyncChain.bitcoin),
        isEmpty,
      );

      clock.advance(const Duration(minutes: 11));
      final replacement = (await second.reconcileAndClaim([
        registration,
      ], chain: WalletSyncChain.bitcoin)).single;
      expect(replacement.leaseToken, isNot(claims.single.leaseToken));
      expect(await first.completeSuccess(claims.single), isFalse);
      expect(await second.completeSuccess(claims.single), isFalse);
      expect(await second.completeSuccess(replacement), isTrue);
      await first.close();
      await second.close();
    },
  );

  test(
    'revision changes wait for a live lease before becoming eligible',
    () async {
      final owner = queue();
      final updater = queue();
      final original = (await owner.reconcileAndClaim([
        _registration(0),
      ], chain: WalletSyncChain.bitcoin)).single;

      expect(
        await updater.reconcileAndClaim([
          _registration(0, revision: 2),
        ], chain: WalletSyncChain.bitcoin),
        isEmpty,
      );
      expect(await owner.renew(original), isTrue);
      clock.advance(const Duration(minutes: 11));

      final replacement = (await updater.reconcileAndClaim([
        _registration(0, revision: 2),
      ], chain: WalletSyncChain.bitcoin)).single;
      expect(replacement.leaseToken, isNot(original.leaseToken));
      expect(await owner.completeSuccess(original), isFalse);
      expect(await updater.completeSuccess(replacement), isTrue);
      await owner.close();
      await updater.close();
    },
  );

  test(
    'active deletion waits for lease release and then removes state',
    () async {
      final owner = queue();
      final reconciler = queue();
      final claim = (await owner.reconcileAndClaim([
        _registration(0),
      ], chain: WalletSyncChain.bitcoin)).single;

      expect(
        await reconciler.reconcileAndClaim(
          const [],
          chain: WalletSyncChain.bitcoin,
        ),
        isEmpty,
      );
      expect(await owner.completeSuccess(claim), isTrue);
      final recreated = await reconciler.reconcileAndClaim([
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
      final claims = await current.reconcileAndClaim([
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
      await current.reconcileAndClaim([
        _registration(0),
      ], chain: WalletSyncChain.bitcoin),
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
      final first = await current.reconcileAndClaim(
        registrations,
        chain: WalletSyncChain.bitcoin,
        maxJobs: 1,
      );
      expect(first.single.key.id, 'wallet-0');
      clock.advance(const Duration(minutes: 11));

      final next = await current.reconcileAndClaim(
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
    final first = await current.reconcileAndClaim(
      registrations,
      chain: WalletSyncChain.bitcoin,
      maxJobs: 1,
    );
    expect(await current.completeSuccess(first.single), isTrue);

    expect(
      await current.reconcileAndClaim(
        registrations,
        chain: WalletSyncChain.bitcoin,
        maxJobs: 1,
        excluding: [first.single.key],
      ),
      isEmpty,
    );
    await current.close();
  });
}

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
