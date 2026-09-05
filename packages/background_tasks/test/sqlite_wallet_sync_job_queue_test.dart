import 'dart:convert';
import 'dart:io';

import 'package:background_tasks/background_tasks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';

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

  SqliteWalletSyncJobQueue queue({WalletSyncLogSink? sink}) =>
      SqliteWalletSyncJobQueue(
        databasePath: path,
        clock: clock.call,
        leaseDuration: const Duration(minutes: 10),
        retryBase: const Duration(minutes: 1),
        logSink: sink ?? _Sink(),
      );

  test('rotates five wallets in stable 2, 2, 1 batches after reopen', () async {
    final registrations = List.generate(5, _registration);
    final seen = <String>[];

    for (var run = 0; run < 4; run++) {
      final current = queue();
      final claims = await current.reconcileAndClaim(
        registrations,
        chain: 'bitcoin',
      );
      seen.addAll(claims.map((claim) => claim.key.walletId));
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
      ], chain: 'bitcoin')).single;
      expect(await current.completeSuccess(first), isTrue);
      clock.advance(const Duration(minutes: 1));

      final neverSynced = await current.reconcileAndClaim([
        _registration(0),
        _registration(1),
      ], chain: 'bitcoin');
      expect(neverSynced.map((claim) => claim.key.walletId), ['wallet-1']);
      expect(await current.completeSuccess(neverSynced.single), isTrue);
      clock.advance(const Duration(minutes: 1));

      final oldestFirst = await current.reconcileAndClaim([
        _registration(0),
        _registration(1),
      ], chain: 'bitcoin');
      expect(oldestFirst.map((claim) => claim.key.walletId), [
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
      ], chain: 'bitcoin')).single;
      expect(await current.completeSuccess(successful), isTrue);
      clock.advance(const Duration(minutes: 1));

      final newWallet = (await current.reconcileAndClaim([
        _registration(0),
        _registration(1),
      ], chain: 'bitcoin')).single;
      expect(newWallet.key.walletId, 'wallet-1');
      expect(
        await current.completeFailure(newWallet, permanent: false),
        isTrue,
      );
      await current.close();
      current = queue();

      final duringBackoff = await current.reconcileAndClaim([
        _registration(0),
        _registration(1),
      ], chain: 'bitcoin');
      expect(duringBackoff.map((claim) => claim.key.walletId), ['wallet-0']);
      expect(await current.completeSuccess(duringBackoff.single), isTrue);
      clock.advance(const Duration(minutes: 1));

      final retry = await current.reconcileAndClaim([
        _registration(0),
        _registration(1),
      ], chain: 'bitcoin');
      expect(retry.map((claim) => claim.key.walletId), ['wallet-1']);
      await current.close();
    },
  );

  test(
    'permanent failure remains disabled until its revision changes',
    () async {
      final current = queue();
      final claim = (await current.reconcileAndClaim([
        _registration(0),
      ], chain: 'bitcoin')).single;
      expect(await current.completeFailure(claim, permanent: true), isTrue);

      expect(
        await current.reconcileAndClaim([_registration(0)], chain: 'bitcoin'),
        isEmpty,
      );
      final changed = await current.reconcileAndClaim([
        _registration(0, revision: 'v2'),
      ], chain: 'bitcoin');
      expect(changed.map((claim) => claim.key.walletId), ['wallet-0']);
      await current.close();
    },
  );

  test(
    'concurrent instances never double-claim and recover expired leases',
    () async {
      final first = queue();
      final second = queue();
      final registration = _registration(0);
      final results = await Future.wait([
        first.reconcileAndClaim([registration], chain: 'bitcoin'),
        second.reconcileAndClaim([registration], chain: 'bitcoin'),
      ]);
      final claims = results.expand((result) => result).toList();
      expect(claims, hasLength(1));
      expect(
        await second.reconcileAndClaim([registration], chain: 'bitcoin'),
        isEmpty,
      );

      clock.advance(const Duration(minutes: 11));
      final replacement = (await second.reconcileAndClaim([
        registration,
      ], chain: 'bitcoin')).single;
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
      ], chain: 'bitcoin')).single;

      expect(
        await updater.reconcileAndClaim([
          _registration(0, revision: 'v2'),
        ], chain: 'bitcoin'),
        isEmpty,
      );
      expect(await owner.renew(original), isTrue);
      clock.advance(const Duration(minutes: 11));

      final replacement = (await updater.reconcileAndClaim([
        _registration(0, revision: 'v2'),
      ], chain: 'bitcoin')).single;
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
      ], chain: 'bitcoin')).single;

      expect(
        await reconciler.reconcileAndClaim(const [], chain: 'bitcoin'),
        isEmpty,
      );
      expect(await owner.completeSuccess(claim), isTrue);
      final recreated = await reconciler.reconcileAndClaim([
        _registration(0),
      ], chain: 'bitcoin');
      expect(recreated.map((entry) => entry.key.walletId), ['wallet-0']);
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
        (
          key: WalletNetworkKey(walletId, 'bitcoin', 'private-network'),
          revision: 'private-revision',
        ),
      ], chain: 'bitcoin');

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
      await current.reconcileAndClaim([_registration(0)], chain: 'bitcoin'),
      hasLength(1),
    );
    await current.close();
  });
}

({WalletNetworkKey key, String revision}) _registration(
  int index, {
  String revision = 'v1',
}) => (
  key: WalletNetworkKey('wallet-$index', 'bitcoin', 'testnet'),
  revision: revision,
);

final class _FakeClock {
  DateTime value;

  _FakeClock(this.value);

  DateTime call() => value;

  void advance(Duration duration) => value = value.add(duration);
}

final class _Sink implements WalletSyncLogSink {
  final List<String>? messages;

  _Sink([this.messages]);

  @override
  void write(WalletSyncLogLevel level, String message) {
    messages?.add(message);
  }
}

final class _ThrowingSink implements WalletSyncLogSink {
  @override
  void write(WalletSyncLogLevel level, String message) {
    throw StateError('logger unavailable');
  }
}
