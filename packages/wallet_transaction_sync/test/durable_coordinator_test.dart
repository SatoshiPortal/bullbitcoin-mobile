import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';

void main() {
  late Directory directory;
  late String path;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('wts-coordinator-');
    path = '${directory.path}/coordination.sqlite';
  });

  tearDown(() => directory.delete(recursive: true));

  test('durable claims have monotone generations and survive reopen', () async {
    final key = const WalletSourceKey('wallet', 'bitcoin', 'testnet');
    final first = DurableWalletSourceOperationCoordinator(databasePath: path);
    late WalletSourceClaim firstClaim;
    await first.runExclusive(key, (session) async {
      firstClaim = (session as WalletSourceClaimedSession).claim;
      expect(firstClaim.generation, 1);
      expect(firstClaim.key, isNot(contains('wallet')));
      session.retire();
    }, kind: WalletOperationKind.delete);

    final reopened = DurableWalletSourceOperationCoordinator(
      databasePath: path,
    );
    await expectLater(
      reopened.runExclusive(key, (_) async {}),
      throwsStateError,
    );
    late WalletSourceClaim nextClaim;
    await reopened.runExclusive(
      key,
      (session) async {
        nextClaim = (session as WalletSourceClaimedSession).claim;
        session.reactivate();
      },
      allowRetired: true,
      kind: WalletOperationKind.reactivate,
    );
    expect(nextClaim.generation, 2);
    expect(nextClaim.ownerToken, isNot(firstClaim.ownerToken));
  });

  test(
    'synchronization slots are shared across keys and coordinator instances',
    () async {
      final first = DurableWalletSourceOperationCoordinator(databasePath: path);
      final second = DurableWalletSourceOperationCoordinator(
        databasePath: path,
      );
      final entered = <String>[];
      final releases = <String, Completer<void>>{};
      final enteredSignals = <String, Completer<void>>{};

      Future<void> hold(
        DurableWalletSourceOperationCoordinator coordinator,
        String wallet,
        String chain,
      ) {
        final release = Completer<void>();
        final signal = Completer<void>();
        releases[wallet] = release;
        enteredSignals[wallet] = signal;
        return coordinator.runExclusive(
          WalletSourceKey(wallet, chain, 'testnet'),
          (_) async {
            entered.add(wallet);
            signal.complete();
            await release.future;
          },
          kind: WalletOperationKind.synchronize,
          timeout: null,
        );
      }

      final bitcoin = hold(first, 'bitcoin-wallet', 'bitcoin');
      final liquid = hold(second, 'liquid-wallet', 'liquid');
      await Future.wait([
        enteredSignals['bitcoin-wallet']!.future,
        enteredSignals['liquid-wallet']!.future,
      ]);
      expect(entered, unorderedEquals(['bitcoin-wallet', 'liquid-wallet']));
      final thirdEntered = Completer<void>();
      final third = second.runExclusive(
        const WalletSourceKey('third-wallet', 'bitcoin', 'testnet'),
        (_) async {
          entered.add('third-wallet');
          thirdEntered.complete();
        },
        kind: WalletOperationKind.discover,
        timeout: null,
      );
      expect(entered, isNot(contains('third-wallet')));
      releases['bitcoin-wallet']!.complete();
      await thirdEntered.future;
      releases['liquid-wallet']!.complete();
      await Future.wait([bitcoin, liquid, third]);
    },
  );

  test('refresh does not consume synchronization capacity', () async {
    final coordinator = DurableWalletSourceOperationCoordinator(
      databasePath: path,
    );
    final firstRelease = Completer<void>();
    final secondRelease = Completer<void>();
    final firstEntered = Completer<void>();
    final secondEntered = Completer<void>();
    final first = coordinator.runExclusive(
      const WalletSourceKey('sync-one', 'bitcoin', 'testnet'),
      (_) async {
        firstEntered.complete();
        await firstRelease.future;
      },
      kind: WalletOperationKind.synchronize,
      timeout: null,
    );
    final second = coordinator.runExclusive(
      const WalletSourceKey('sync-two', 'liquid', 'testnet'),
      (_) async {
        secondEntered.complete();
        await secondRelease.future;
      },
      kind: WalletOperationKind.synchronize,
      timeout: null,
    );
    await Future.wait([firstEntered.future, secondEntered.future]);
    final third = coordinator.runExclusive(
      const WalletSourceKey('sync-three', 'bitcoin', 'testnet'),
      (_) async {},
      kind: WalletOperationKind.synchronize,
      timeout: null,
    );
    final thirdHash = sha256
        .convert('sync-three\u0000bitcoin\u0000testnet'.codeUnits)
        .toString();
    var thirdPending = false;
    for (var attempt = 0; attempt < 100; attempt++) {
      final db = sqlite3.open(path);
      final pending = db.select(
        "SELECT request_token FROM requests WHERE key_hash=? AND status='pending'",
        [thirdHash],
      );
      db.dispose();
      if (pending.isNotEmpty) {
        thirdPending = true;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(thirdPending, isTrue);
    final refreshed = Completer<void>();
    final refresh = coordinator.runExclusive(
      const WalletSourceKey('local-read', 'bitcoin', 'testnet'),
      (_) async => refreshed.complete(),
      kind: WalletOperationKind.refresh,
    );
    await refreshed.future;
    firstRelease.complete();
    secondRelease.complete();
    await Future.wait([first, second, third, refresh]);
  });

  test(
    'capacity is validated and a timed-out caller retains its slot',
    () async {
      expect(
        () => DurableWalletSourceOperationCoordinator(
          databasePath: path,
          maxActiveSynchronizations: 0,
        ),
        throwsArgumentError,
      );
      final coordinator = DurableWalletSourceOperationCoordinator(
        databasePath: path,
        maxActiveSynchronizations: 1,
        acquisitionTimeout: const Duration(milliseconds: 30),
      );
      final release = Completer<void>();
      final owner = coordinator.runExclusive(
        const WalletSourceKey('timeout-owner', 'bitcoin', 'testnet'),
        (_) => release.future,
        kind: WalletOperationKind.synchronize,
        timeout: const Duration(milliseconds: 10),
      );
      await expectLater(owner, throwsA(isA<TimeoutException>()));
      final blocked = coordinator.runExclusive(
        const WalletSourceKey('timeout-contender', 'bitcoin', 'testnet'),
        (_) async {},
        kind: WalletOperationKind.synchronize,
        timeout: const Duration(milliseconds: 30),
      );
      await expectLater(blocked, throwsA(isA<TimeoutException>()));
      release.complete();
      final cleanupProbe = coordinator.runExclusive(
        const WalletSourceKey('cleanup-probe', 'bitcoin', 'testnet'),
        (_) async {},
        kind: WalletOperationKind.synchronize,
        timeout: null,
      );
      await cleanupProbe;

      final mismatch = DurableWalletSourceOperationCoordinator(
        databasePath: path,
        maxActiveSynchronizations: 2,
      );
      await expectLater(
        mismatch.runExclusive(
          const WalletSourceKey('mismatch', 'bitcoin', 'testnet'),
          (_) async {},
        ),
        throwsStateError,
      );
    },
  );

  test('retire and reactivate commands are applied in session order', () async {
    const key = WalletSourceKey('ordered', 'bitcoin', 'testnet');
    final coordinator = DurableWalletSourceOperationCoordinator(
      databasePath: path,
    );

    await coordinator.runExclusive(
      key,
      (session) async {
        session.retire();
        session.reactivate();
      },
      allowRetired: true,
      kind: WalletOperationKind.reactivate,
    );

    expect(await coordinator.runExclusive(key, (_) async => 1), 1);
  });

  test(
    'same key is held through a timeout, while another key proceeds',
    () async {
      final coordinator = DurableWalletSourceOperationCoordinator(
        databasePath: path,
      );
      final release = Completer<void>();
      final key = const WalletSourceKey('same', 'bitcoin', 'testnet');
      final timed = coordinator.runExclusive(key, (session) async {
        await release.future;
        return 1;
      }, timeout: const Duration(milliseconds: 10));
      await expectLater(timed, throwsA(isA<TimeoutException>()));
      var entered = false;
      final waiting = coordinator.runExclusive(key, (_) async {
        entered = true;
        return 2;
      });
      expect(
        await coordinator.runExclusive(
          const WalletSourceKey('other', 'bitcoin', 'testnet'),
          (_) async => 3,
        ),
        3,
      );
      expect(entered, isFalse);
      release.complete();
      expect(await waiting, 2);
    },
  );

  test('foreground requests precede queued background requests', () async {
    final coordinator = DurableWalletSourceOperationCoordinator(
      databasePath: path,
    );
    await coordinator.runExclusive(
      const WalletSourceKey('bootstrap', 'bitcoin', 'testnet'),
      (_) async {},
    );
    final release = Completer<void>();
    final ownerEntered = Completer<void>();
    const key = WalletSourceKey('priority', 'bitcoin', 'testnet');
    final owner = coordinator.runExclusive(
      key,
      (_) async {
        ownerEntered.complete();
        await release.future;
      },
      kind: WalletOperationKind.synchronize,
      timeout: null,
    );
    await ownerEntered.future;
    final order = <String>[];
    final background = coordinator.runExclusive(key, (_) async {
      order.add('background');
    }, priority: WalletOperationPriority.background);
    final hash = sha256
        .convert('priority\u0000bitcoin\u0000testnet'.codeUnits)
        .toString();
    var backgroundQueued = false;
    for (var attempt = 0; attempt < 100; attempt++) {
      final db = sqlite3.open(path);
      final pending = db.select(
        "SELECT request_token FROM requests WHERE key_hash=? AND priority='background' AND status IN ('pending', 'active')",
        [hash],
      );
      db.dispose();
      if (pending.isNotEmpty) {
        backgroundQueued = true;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(backgroundQueued, isTrue);
    final foreground = coordinator.runExclusive(key, (_) async {
      order.add('foreground');
    });
    var foregroundQueued = false;
    for (var attempt = 0; attempt < 100; attempt++) {
      final db = sqlite3.open(path);
      final pending = db.select(
        "SELECT request_token FROM requests WHERE key_hash=? AND priority='foreground' AND status IN ('pending', 'active')",
        [hash],
      );
      db.dispose();
      if (pending.length > 1) {
        foregroundQueued = true;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(foregroundQueued, isTrue);
    release.complete();
    await Future.wait([owner, background, foreground]);
    expect(order, ['foreground', 'background']);
  });

  test(
    'global synchronization admission is foreground-first then FIFO',
    () async {
      final coordinator = DurableWalletSourceOperationCoordinator(
        databasePath: path,
        maxActiveSynchronizations: 1,
      );
      final ownerEntered = Completer<void>();
      final ownerRelease = Completer<void>();
      final owner = coordinator.runExclusive(
        const WalletSourceKey('global-owner', 'bitcoin', 'testnet'),
        (_) async {
          ownerEntered.complete();
          await ownerRelease.future;
        },
        kind: WalletOperationKind.synchronize,
        timeout: null,
      );
      await ownerEntered.future;

      final order = <String>[];
      Future<void> enqueue(String wallet, WalletOperationPriority priority) =>
          coordinator.runExclusive(
            WalletSourceKey(wallet, 'bitcoin', 'testnet'),
            (_) async => order.add(wallet),
            kind: WalletOperationKind.synchronize,
            priority: priority,
            timeout: null,
          );

      final background = enqueue(
        'global-background',
        WalletOperationPriority.background,
      );
      await _waitForPendingSynchronizations(path, 1);
      final firstForeground = enqueue(
        'global-foreground-one',
        WalletOperationPriority.foreground,
      );
      await _waitForPendingSynchronizations(path, 2);
      final secondForeground = enqueue(
        'global-foreground-two',
        WalletOperationPriority.foreground,
      );
      await _waitForPendingSynchronizations(path, 3);

      ownerRelease.complete();
      await Future.wait([owner, background, firstForeground, secondForeground]);
      expect(order, [
        'global-foreground-one',
        'global-foreground-two',
        'global-background',
      ]);
    },
  );

  test(
    'same-key pending sync does not consume the second global slot',
    () async {
      final coordinator = DurableWalletSourceOperationCoordinator(
        databasePath: path,
      );
      const sharedKey = WalletSourceKey('shared-wallet', 'bitcoin', 'testnet');
      final firstEntered = Completer<void>();
      final firstRelease = Completer<void>();
      final first = coordinator.runExclusive(
        sharedKey,
        (_) async {
          firstEntered.complete();
          await firstRelease.future;
        },
        kind: WalletOperationKind.synchronize,
        timeout: null,
      );
      await firstEntered.future;

      final secondEntered = Completer<void>();
      final secondRelease = Completer<void>();
      final second = coordinator.runExclusive(
        sharedKey,
        (_) async {
          secondEntered.complete();
          await secondRelease.future;
        },
        kind: WalletOperationKind.synchronize,
        timeout: null,
      );
      await _waitForPendingSynchronizations(path, 1);

      final otherEntered = Completer<void>();
      final otherRelease = Completer<void>();
      final other = coordinator.runExclusive(
        const WalletSourceKey('independent-wallet', 'liquid', 'testnet'),
        (_) async {
          otherEntered.complete();
          await otherRelease.future;
        },
        kind: WalletOperationKind.synchronize,
        timeout: null,
      );
      await otherEntered.future;
      expect(secondEntered.isCompleted, isFalse);

      firstRelease.complete();
      await secondEntered.future;
      otherRelease.complete();
      secondRelease.complete();
      await Future.wait([first, second, other]);
    },
  );

  test(
    'stale pending requests are purged, but active owners are not',
    () async {
      final coordinator = DurableWalletSourceOperationCoordinator(
        databasePath: path,
        pendingHeartbeatTimeout: const Duration(milliseconds: 1),
        acquisitionTimeout: const Duration(milliseconds: 200),
      );
      const key = WalletSourceKey('stale', 'bitcoin', 'testnet');
      await coordinator.runExclusive(key, (_) async {});
      final hash = sha256
          .convert('stale\u0000bitcoin\u0000testnet'.codeUnits)
          .toString();
      final db = sqlite3.open(path);
      db.execute(
        '''INSERT INTO requests
        (request_token, key_hash, kind, priority, status, requested_at, heartbeat_at)
        VALUES (?,?,?,?,?,?,?)''',
        ['stale-request', hash, 'refresh', 'foreground', 'pending', 1, 1],
      );
      db.dispose();
      expect(await coordinator.runExclusive(key, (_) async => 1), 1);

      final release = Completer<void>();
      final owner = coordinator.runExclusive(
        key,
        (_) => release.future,
        timeout: null,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final blockedCoordinator = DurableWalletSourceOperationCoordinator(
        databasePath: path,
        pendingHeartbeatTimeout: const Duration(milliseconds: 1),
        acquisitionTimeout: const Duration(milliseconds: 30),
      );
      final blocked = blockedCoordinator.runExclusive(key, (_) async => 2);
      await expectLater(blocked, throwsA(isA<TimeoutException>()));
      release.complete();
      await owner;
    },
  );

  test(
    'stale pending sync on another key cannot block global admission',
    () async {
      final coordinator = DurableWalletSourceOperationCoordinator(
        databasePath: path,
        pendingHeartbeatTimeout: const Duration(milliseconds: 1),
        acquisitionTimeout: const Duration(milliseconds: 200),
      );
      await coordinator.runExclusive(
        const WalletSourceKey('schema-bootstrap', 'bitcoin', 'testnet'),
        (_) async {},
      );
      final staleHash = sha256
          .convert('dead-pending bitcoin testnet'.codeUnits)
          .toString();
      final db = sqlite3.open(path);
      db.execute(
        '''INSERT INTO requests
      (request_token, key_hash, kind, priority, status, requested_at, heartbeat_at)
      VALUES (?,?,?,?,?,?,?)''',
        [
          'dead-request',
          staleHash,
          'synchronize',
          'foreground',
          'pending',
          1,
          1,
        ],
      );
      db.dispose();

      final entered = await coordinator.runExclusive(
        const WalletSourceKey('live-request', 'liquid', 'testnet'),
        (_) async => true,
        kind: WalletOperationKind.synchronize,
        timeout: null,
      );
      expect(entered, isTrue);
      final check = sqlite3.open(path);
      expect(
        check.select('SELECT * FROM requests WHERE request_token=?', [
          'dead-request',
        ]),
        isEmpty,
      );
      check.dispose();
    },
  );

  test(
    'cooperative isolate teardown releases the mutex for a later coordinator',
    () async {
      final ready = ReceivePort();
      final commands = ReceivePort();
      final exited = ReceivePort();
      final isolate = await Isolate.spawn(_holdInIsolate, [
        path,
        ready.sendPort,
        commands.sendPort,
      ]);
      isolate.addOnExitListener(exited.sendPort, response: true);
      await ready.first.timeout(const Duration(seconds: 2));
      final workerCommands =
          await commands.first.timeout(const Duration(seconds: 2)) as SendPort;
      var entered = false;
      final second =
          DurableWalletSourceOperationCoordinator(
            databasePath: path,
            busyTimeout: const Duration(milliseconds: 1),
            acquisitionTimeout: null,
          ).runExclusive(
            const WalletSourceKey('isolate', 'bitcoin', 'testnet'),
            (_) async {
              entered = true;
            },
            timeout: null,
          );
      await expectLater(
        Future.any<void>([
          second,
          Future<void>.delayed(
            const Duration(milliseconds: 100),
            () => throw TimeoutException('contender remained blocked'),
          ),
        ]),
        throwsA(isA<TimeoutException>()),
      );
      expect(entered, isFalse);
      workerCommands.send(null);
      await exited.first.timeout(const Duration(seconds: 2));
      await second;
      final third = DurableWalletSourceOperationCoordinator(databasePath: path);
      expect(
        await third.runExclusive(
          const WalletSourceKey('isolate', 'bitcoin', 'testnet'),
          (_) async => 3,
        ),
        3,
      );
      ready.close();
      commands.close();
      exited.close();
    },
  );

  test(
    'orphaned claim and request are replaced with the next generation',
    () async {
      const key = WalletSourceKey('orphan', 'bitcoin', 'testnet');
      final hash = sha256
          .convert('orphan\u0000bitcoin\u0000testnet'.codeUnits)
          .toString();
      final coordinator = DurableWalletSourceOperationCoordinator(
        databasePath: path,
      );
      await coordinator.runExclusive(key, (_) async {});
      final db = sqlite3.open(path);
      db.execute('INSERT OR REPLACE INTO generations VALUES (?,?)', [hash, 7]);
      db.execute('INSERT INTO claims VALUES (?,?,?,?,?,?)', [
        hash,
        7,
        'orphan-owner',
        'refresh',
        'foreground',
        1,
      ]);
      db.execute(
        '''INSERT INTO requests
        (request_token, key_hash, kind, priority, status, requested_at, heartbeat_at)
        VALUES (?,?,?,?,?,?,?)''',
        ['orphan-request', hash, 'refresh', 'foreground', 'active', 1, 1],
      );
      db.dispose();

      late WalletSourceClaim claim;
      await coordinator.runExclusive(key, (session) async {
        claim = (session as WalletSourceClaimedSession).claim;
        expect(claim.generation, 8);
      });
      final check = sqlite3.open(path);
      expect(
        check.select('SELECT * FROM claims WHERE key_hash=?', [hash]),
        isEmpty,
      );
      expect(
        check.select('SELECT * FROM requests WHERE key_hash=?', [hash]),
        isEmpty,
      );
      check.dispose();
    },
  );

  test(
    'a claimed durable session closes after a successful operation',
    () async {
      final coordinator = DurableWalletSourceOperationCoordinator(
        databasePath: path,
      );
      late WalletSourceClaimedSession session;
      await coordinator.runExclusive(
        const WalletSourceKey('closed', 'bitcoin', 'testnet'),
        (value) async {
          session = value as WalletSourceClaimedSession;
        },
      );
      expect(session.isClosed, isTrue);
      expect(session.ensureOpen, throwsStateError);
    },
  );

  test('normal release acknowledges before the worker terminates', () async {
    final coordinator = DurableWalletSourceOperationCoordinator(
      databasePath: path,
    );

    expect(
      await coordinator.runExclusive(
        const WalletSourceKey('release-ack', 'bitcoin', 'testnet'),
        (_) async => 7,
      ),
      7,
    );
  });

  test('lock filenames contain only the hashed key', () async {
    final coordinator = DurableWalletSourceOperationCoordinator(
      databasePath: path,
    );
    await coordinator.runExclusive(
      const WalletSourceKey('wallet/sentinel', 'chain?', 'network:sentinel'),
      (_) async {},
    );
    final files = Directory(
      coordinator.lockDirectoryPath,
    ).listSync().whereType<File>().toList();
    expect(files, hasLength(1));
    expect(
      Uri.file(files.single.path).pathSegments.last,
      matches(RegExp(r'^[0-9a-f]{64}\.sqlite$')),
    );
    expect(files.single.path, isNot(contains('wallet/sentinel')));
  });

  test(
    'an admission timeout does not delete the active owner request',
    () async {
      final coordinator = DurableWalletSourceOperationCoordinator(
        databasePath: path,
      );
      const key = WalletSourceKey('active-owner', 'bitcoin', 'testnet');
      final release = Completer<void>();
      final owner = coordinator.runExclusive(
        key,
        (_) => release.future,
        timeout: null,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final contender = DurableWalletSourceOperationCoordinator(
        databasePath: path,
        acquisitionTimeout: const Duration(milliseconds: 30),
      );
      await expectLater(
        contender.runExclusive(key, (_) async {}),
        throwsA(isA<TimeoutException>()),
      );
      final hash = sha256
          .convert('active-owner\u0000bitcoin\u0000testnet'.codeUnits)
          .toString();
      final db = sqlite3.open(path);
      expect(
        db.select("SELECT * FROM claims WHERE key_hash=?", [hash]),
        hasLength(1),
      );
      expect(
        db.select(
          "SELECT * FROM requests WHERE key_hash=? AND status='active'",
          [hash],
        ),
        hasLength(1),
      );
      db.dispose();
      release.complete();
      await owner;
    },
  );

  test('claim cleanup failure still releases the mutex', () async {
    var fail = true;
    final first = DurableWalletSourceOperationCoordinator(
      databasePath: path,
      beforeClaimRelease: () {
        if (fail) {
          fail = false;
          throw StateError('cleanup failure');
        }
      },
    );
    const key = WalletSourceKey('cleanup', 'bitcoin', 'testnet');
    await expectLater(first.runExclusive(key, (_) async {}), throwsStateError);
    final second = DurableWalletSourceOperationCoordinator(databasePath: path);
    expect(await second.runExclusive(key, (_) async => 2), 2);
  });

  test('worker release failure still cleans up the mutex and actor', () async {
    const key = WalletSourceKey('release-failure', 'bitcoin', 'testnet');
    final failing = DurableWalletSourceOperationCoordinator(
      databasePath: path,
      failReleaseCleanup: true,
    );

    await expectLater(
      failing.runExclusive(key, (_) async {}),
      throwsStateError,
    );

    final later = DurableWalletSourceOperationCoordinator(
      databasePath: path,
      acquisitionTimeout: const Duration(milliseconds: 200),
    );
    expect(await later.runExclusive(key, (_) async => 2), 2);
  });

  test('coordination logs are correlated without source identifiers', () async {
    final events = <WalletCoordinationLogEvent>[];
    final coordinator = DurableWalletSourceOperationCoordinator(
      databasePath: path,
      logSink: events.add,
    );
    const sensitiveWalletId = 'never-log-this-wallet-id';

    await coordinator.runExclusive(
      const WalletSourceKey(sensitiveWalletId, 'bitcoin', 'testnet'),
      (_) async {},
      kind: WalletOperationKind.synchronize,
      timeout: null,
    );

    expect(events.map((event) => event.level), [
      WalletCoordinationLogLevel.config,
      WalletCoordinationLogLevel.config,
      WalletCoordinationLogLevel.fine,
    ]);
    final messages = events.map((event) => event.message).join('\n');
    final sourceHash = sha256
        .convert('$sensitiveWalletId\u0000bitcoin\u0000testnet'.codeUnits)
        .toString();
    expect(messages, isNot(contains(sensitiveWalletId)));
    expect(messages, isNot(contains(sourceHash)));
    expect(messages, contains('kind=synchronize'));
    expect(messages, contains('priority=foreground'));
    expect(messages, contains('chain=bitcoin'));
    expect(messages, contains('network=testnet'));
    final tokens = RegExp(
      r'operation=([0-9a-f]{16})',
    ).allMatches(messages).map((match) => match.group(1)).toSet();
    expect(tokens, hasLength(1));
  });

  test('operation failures log only a fixed category', () async {
    final events = <WalletCoordinationLogEvent>[];
    final coordinator = DurableWalletSourceOperationCoordinator(
      databasePath: path,
      logSink: events.add,
    );
    const sensitiveFailure = 'server.example.invalid wallet-secret';

    await expectLater(
      coordinator.runExclusive<void>(
        const WalletSourceKey('failure-wallet', 'bitcoin', 'testnet'),
        (_) => throw Exception(sensitiveFailure),
        kind: WalletOperationKind.synchronize,
        timeout: null,
      ),
      throwsException,
    );

    final warnings = events
        .where((event) => event.level == WalletCoordinationLogLevel.warning)
        .map((event) => event.message)
        .join('\n');
    expect(warnings, contains('category=unexpected'));
    expect(warnings, isNot(contains(sensitiveFailure)));
    expect(warnings, isNot(contains('failure-wallet')));
  });

  test('operation and cleanup failures retain both fixed categories', () async {
    final events = <WalletCoordinationLogEvent>[];
    final coordinator = DurableWalletSourceOperationCoordinator(
      databasePath: path,
      logSink: events.add,
      beforeClaimRelease: () => throw StateError('cleanup-secret'),
    );

    await expectLater(
      coordinator.runExclusive<void>(
        const WalletSourceKey('double-failure', 'bitcoin', 'testnet'),
        (_) => throw Exception('operation-secret'),
        kind: WalletOperationKind.synchronize,
        timeout: null,
      ),
      throwsStateError,
    );

    final warnings = events
        .where((event) => event.level == WalletCoordinationLogLevel.warning)
        .map((event) => event.message)
        .join('\n');
    expect(warnings, contains('cleanup failed'));
    expect(warnings, contains('category=state'));
    expect(warnings, contains('operation failed'));
    expect(warnings, contains('category=unexpected'));
    expect(warnings, isNot(contains('cleanup-secret')));
    expect(warnings, isNot(contains('operation-secret')));
    expect(warnings, isNot(contains('double-failure')));
  });

  test('a failing log sink cannot alter synchronization', () async {
    final coordinator = DurableWalletSourceOperationCoordinator(
      databasePath: path,
      logSink: (_) => throw StateError('logger unavailable'),
    );

    expect(
      await coordinator.runExclusive(
        const WalletSourceKey('log-failure', 'liquid', 'mainnet'),
        (_) async => 42,
        kind: WalletOperationKind.synchronize,
        timeout: null,
      ),
      42,
    );
  });

  test(
    'registered actors can acquire independently during slow startup',
    () async {
      for (var iteration = 0; iteration < 20; iteration++) {
        final key = WalletSourceKey(
          'slow-start-$iteration',
          'bitcoin',
          'testnet',
        );
        final order = <String>[];
        final slow = DurableWalletSourceOperationCoordinator(
          databasePath: path,
          workerInitializationDelay: const Duration(milliseconds: 150),
        );
        final fast = DurableWalletSourceOperationCoordinator(
          databasePath: path,
        );
        final first = slow.runExclusive(key, (_) async {
          order.add('slow');
        });
        final second = fast.runExclusive(key, (_) async {
          order.add('fast');
        });

        await Future.wait([first, second]);
        expect(order, ['slow', 'fast']);
      }
    },
  );

  test('an actor exit fails the operation without hanging release', () async {
    final coordinator = DurableWalletSourceOperationCoordinator(
      databasePath: path,
      killWorkerAfterReady: true,
    );
    final operation = coordinator.runExclusive(
      const WalletSourceKey('dead-worker', 'bitcoin', 'testnet'),
      (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      },
      timeout: null,
      kind: WalletOperationKind.synchronize,
    );

    await expectLater(
      Future.any<void>([
        operation,
        Future<void>.delayed(
          const Duration(seconds: 2),
          () => throw TimeoutException('dead actor did not settle'),
        ),
      ]),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'a non-retryable lock path fails instead of leaving a pending future',
    () async {
      final file = File('${directory.path}/not-a-directory')
        ..writeAsStringSync('x');
      final coordinator = DurableWalletSourceOperationCoordinator(
        databasePath: path,
        lockDirectoryPath: '${file.path}/child',
      );
      await expectLater(
        coordinator.runExclusive(
          const WalletSourceKey('bad-path', 'bitcoin', 'testnet'),
          (_) async {},
        ),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  test('worker initialization does not starve the caller isolate', () async {
    final coordinator = DurableWalletSourceOperationCoordinator(
      databasePath: path,
      workerInitializationDelay: const Duration(milliseconds: 100),
    );
    var beats = 0;
    final heartbeat = Timer.periodic(const Duration(milliseconds: 10), (_) {
      beats++;
    });
    await coordinator.runExclusive(
      const WalletSourceKey('heartbeat', 'bitcoin', 'testnet'),
      (_) async {},
    );
    heartbeat.cancel();
    expect(beats, greaterThanOrEqualTo(5));
  });
}

Future<void> _waitForPendingSynchronizations(String path, int count) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    final db = sqlite3.open(path);
    try {
      final rows = db.select(
        "SELECT request_token FROM requests WHERE status='pending' AND kind IN ('synchronize', 'discover')",
      );
      if (rows.length >= count) return;
    } finally {
      db.dispose();
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw TimeoutException('Expected $count pending synchronization requests');
}

Future<void> _holdInIsolate(List<Object> args) async {
  final path = args[0] as String;
  final ready = args[1] as SendPort;
  final commands = ReceivePort();
  (args[2] as SendPort).send(commands.sendPort);
  final coordinator = DurableWalletSourceOperationCoordinator(
    databasePath: path,
  );
  await coordinator.runExclusive(
    const WalletSourceKey('isolate', 'bitcoin', 'testnet'),
    (_) async {
      ready.send(null);
      await commands.first;
    },
    timeout: null,
  );
  commands.close();
}
