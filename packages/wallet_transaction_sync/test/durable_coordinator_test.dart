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
      db.execute('INSERT INTO requests VALUES (?,?,?,?,?,?)', [
        'stale-request',
        hash,
        'foreground',
        'pending',
        1,
        1,
      ]);
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
      db.execute('INSERT INTO requests VALUES (?,?,?,?,?,?)', [
        'orphan-request',
        hash,
        'foreground',
        'active',
        1,
        1,
      ]);
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
