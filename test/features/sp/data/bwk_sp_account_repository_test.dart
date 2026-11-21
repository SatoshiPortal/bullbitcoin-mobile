import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/features/sp/data/bwk_sp_account_repository.dart';
import 'package:bb_mobile/features/sp/data/datasources/bwk_sp_account_datasource.dart';
import 'package:bb_mobile/features/sp/data/datasources/sp_account_files_datasource.dart';
import 'package:bb_mobile/features/sp/data/sp_storage_names.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_tx_draft.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_update.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:rust_bindings/bwk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show Secret;

import '../sp_fakes.dart';

// Tests for the live-session side of the adapter. No real FFI session is ever
// established: the datasource is injected, so a fake stands in for the Rust
// account and every error the boundary is supposed to map can be thrown at it.
// The account directory has its own adapter and its own test.

/// Stands in for the bwk FFI. [disposeError] models a "dispose timed out",
/// where the inner lock is still held.
class _FakeFfiDatasource extends BwkSpAccountDatasource {
  _FakeFfiDatasource({
    this.session = true,
    this.disposeError,
    this.stopScanError,
    this.scanOnceError,
    this.restampError,
    this.notifications = const Stream.empty(),
  });

  final Object? disposeError;
  final Object? stopScanError;
  final Object? scanOnceError;
  final Object? restampError;
  final Stream<SpNotification> notifications;
  bool session;
  int restampCalls = 0;
  int balanceReads = 0;
  int stopCalls = 0;
  final scanStarts = <int?>[];
  Future<void> Function()? onClearScanState;
  BigInt? changeDustThreshold;
  // Holds restartElectrum open until completed, when set.
  Completer<void>? restart;

  @override
  bool get hasSession => session;

  @override
  Future<void> dispose() async {
    final error = disposeError;
    if (error != null) throw error;
    session = false;
  }

  @override
  Future<void> stopScan() async {
    stopCalls++;
    final error = stopScanError;
    if (error != null) throw error;
  }

  @override
  Future<void> scanOnce({int? startHeight}) async {
    final error = scanOnceError;
    if (error != null) throw error;
    scanStarts.add(startHeight);
  }

  @override
  int? lastScannedHeight() => null;

  @override
  Future<void> clearScanState() async => onClearScanState?.call();

  @override
  Stream<SpNotification> init() => notifications;

  @override
  bool restampMissingTimestamps() {
    restampCalls++;
    final error = restampError;
    if (error != null) throw error;
    return true;
  }

  @override
  Future<void> restartElectrum() => restart?.future ?? Future.value();

  @override
  String spAddress() => 'sp1test';

  @override
  SpBalanceView unifiedBalance() {
    balanceReads++;
    return SpBalanceView(
      confirmedSat: BigInt.from(1000),
      totalUnifiedSat: BigInt.from(1000),
      lastScannedHeight: 709656,
    );
  }

  @override
  Future<(String, TxSimulation)> preparePsbt({
    required List<RecipientView> recipients,
    required BigInt feerateSatVb,
    required BigInt changeDustThreshold,
  }) async {
    this.changeDustThreshold = changeDustThreshold;
    return (
      '0',
      TxSimulation(
        inputs: const [],
        outputs: const [],
        feeSat: BigInt.zero,
        changeSat: BigInt.zero,
      ),
    );
  }
}

class _OpeningFfiDatasource extends _FakeFfiDatasource {
  _OpeningFfiDatasource() : super(session: false);

  final opening = Completer<void>();
  final finishOpen = Completer<void>();

  @override
  Future<void> createFromSecret({
    required SpNetwork network,
    required Secret secret,
    required String blindbitUrl,
    required String electrumUrl,
    required String dataDir,
    required int fetchConcurrencyFactor,
    required int matchConcurrencyFactor,
    int minScanAmountSat = SpConfig.defaultMinScanAmountSat,
    required SpHeaderCheckpoint? headerCheckpoint,
  }) async {
    opening.complete();
    await finishOpen.future;
    session = true;
  }

  @override
  void setElectrumUrl(String url) {}

  @override
  Future<void> startElectrum() async {}
}

class _PendingScanFiles extends SpAccountFilesDatasource {
  Future<void> Function(({int? startHeight, bool isPaused})?)? beforeWrite;

  @override
  Future<void> writePendingScan(
    String dataDir,
    ({int? startHeight, bool isPaused})? pending,
  ) async {
    await beforeWrite?.call(pending);
    await super.writePendingScan(dataDir, pending);
  }
}

void main() {
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('sp_repo_test_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          return tempDir.path;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {
        // best-effort; some tests intentionally leave locked state
      }
    }
  });

  BwkSpAccountRepository makeRepo({
    BwkSpAccountDatasource? ffi,
    SpAccountFilesDatasource? files,
  }) => BwkSpAccountRepository(
    ffi: ffi ?? BwkSpAccountDatasource(),
    files: files ?? SpAccountFilesDatasource(),
  );

  Directory accountDirOf() =>
      Directory('${tempDir.path}/${SpStorageNames.accountName}');

  Future<Result<void, SpFailure>> createOn(BwkSpAccountRepository repo) async =>
      repo.createFromSecret(
        network: BitcoinNetwork.mainnet,
        secret: await spSecret(),
        blindbitUrl: 'http://blindbit.example',
        electrumUrl: 'tcp://electrum.example:50001',
      );

  test('snapshot uses the scan height returned with the balance', () {
    final ffi = _FakeFfiDatasource();
    final result = makeRepo(ffi: ffi).snapshot();

    expect(
      result,
      isA<Ok<SpWallet, SpFailure>>().having(
        (snapshot) => snapshot.value.lastScannedHeight,
        'lastScannedHeight',
        709656,
      ),
    );
    expect(ffi.balanceReads, 1);
  });

  group('createFromSecret lock clearing', () {
    test(
      'clears every stale advisory lock before opening the account',
      () async {
        accountDirOf().createSync();
        final locks = [
          for (final name in SpStorageNames.lockFiles)
            File('${accountDirOf().path}/$name')..writeAsStringSync(''),
        ];
        expect(locks.every((f) => f.existsSync()), isTrue);

        // The FFI create cannot run in a unit test, so it fails. The lock
        // clearing happens first, which is what this asserts.
        await createOn(makeRepo(ffi: _FakeFfiDatasource(session: false)));

        expect(locks.every((f) => f.existsSync()), isFalse);
      },
    );

    test('the header store lock is one of the cleared locks', () {
      expect(SpStorageNames.lockFiles, contains(SpStorageNames.headerLockFile));
    });
  });

  group('createFromSecret single-owner guard', () {
    test('a live session is refused instead of opening a second one', () async {
      final repo = makeRepo(ffi: _FakeFfiDatasource());

      final created = await createOn(repo);

      expect(
        (created as Err<void, SpFailure>).failure,
        isA<SpSessionBusy>(),
        reason: 'a second live SpAccount would leak the first one',
      );
      expect(repo.hasSession, isTrue, reason: 'the guard disposes nothing');
      expect(accountDirOf().existsSync(), isFalse);
    });

    test('the refused create leaves the stale locks alone', () async {
      // The strong form of "bails before doing any work": lock clearing runs
      // right after the guard, so a surviving lock pins the early return.
      accountDirOf().createSync();
      final lock = File('${accountDirOf().path}/${SpStorageNames.lockFile}')
        ..writeAsStringSync('');

      await createOn(makeRepo(ffi: _FakeFfiDatasource()));

      expect(lock.existsSync(), isTrue);
    });
  });

  group('dispose stream teardown', () {
    test('disposal waits for a cold open and rejects parallel opens', () async {
      final ffi = _OpeningFfiDatasource();
      final repo = makeRepo(ffi: ffi);
      final opening = createOn(repo);
      await ffi.opening.future;

      var didDispose = false;
      final disposing = repo.dispose().then((result) {
        didDispose = true;
        return result;
      });
      try {
        final parallel = await createOn(repo);
        expect(
          (parallel as Err<void, SpFailure>).failure,
          isA<SpSessionBusy>(),
        );
        expect(didDispose, isFalse);
      } finally {
        ffi.finishOpen.complete();
      }
      expect(await opening, isA<Ok<void, SpFailure>>());
      expect(await disposing, isA<Ok<void, SpFailure>>());
      expect(repo.hasSession, isFalse);
    });

    test(
      'a clean session dispose tears down the notification streams',
      () async {
        final repo = makeRepo(ffi: _FakeFfiDatasource());

        expect(await repo.dispose(), isA<Ok<void, SpFailure>>());

        expect(repo.notifStreamTornDown, isTrue);
      },
    );

    test(
      'a timed-out session dispose keeps the streams and session live',
      () async {
        final repo = makeRepo(
          ffi: _FakeFfiDatasource(
            disposeError: const SpError.disposeTimedOut(),
          ),
        );

        final disposed = await repo.dispose();

        expect(
          (disposed as Err<void, SpFailure>).failure,
          isA<SpSessionBusy>(),
          reason: 'the timeout must reach the caller as its own failure',
        );
        // The stream plumbing is NOT torn down, so the still-live session keeps
        // pushing notifications instead of going dark on a transient timeout.
        expect(repo.notifStreamTornDown, isFalse);
        expect(repo.hasSession, isTrue);
        expect(repo.isScanningCached, isFalse);
      },
    );

    test('dispose with no session is a no-op', () async {
      final repo = makeRepo(ffi: _FakeFfiDatasource(session: false));

      expect(await repo.dispose(), isA<Ok<void, SpFailure>>());
      expect(repo.notifStreamTornDown, isFalse);
    });
  });

  group('header tip', () {
    test('a header extension below the tip does not lower it', () async {
      final ffi = StreamController<SpNotification>();
      addTearDown(ffi.close);
      final repo = makeRepo(ffi: _FakeFfiDatasource(notifications: ffi.stream));
      final tips = <int>[];
      final updates = repo.updates.listen((update) {
        if (update is SpChainTipChanged) tips.add(update.tip);
      });
      addTearDown(updates.cancel);
      final sub = repo.notifications.listen((_) {});
      addTearDown(sub.cancel);

      ffi
        ..add(
          const SpNotification.headerProgressStarted(
            phase: HeaderProgressPhase.initialSync,
            start: 900000,
            end: 970180,
          ),
        )
        ..add(
          const SpNotification.headerProgressCompleted(
            phase: HeaderProgressPhase.initialSync,
          ),
        )
        // Extension down to an old coin: same phase, a range below the tip.
        ..add(
          const SpNotification.headerProgressStarted(
            phase: HeaderProgressPhase.initialSync,
            start: 800000,
            end: 899999,
          ),
        );
      await Future<void>.delayed(Duration.zero);

      expect(repo.chainTip(), 970180);
      expect(tips, [970180]);
    });
  });

  group('balance read on notification', () {
    test('waits for an electrum restart to end', () async {
      final notifications = StreamController<SpNotification>();
      addTearDown(notifications.close);
      final ffi = _FakeFfiDatasource(notifications: notifications.stream)
        ..restart = Completer<void>();
      final repo = makeRepo(ffi: ffi);
      final balances = <SpBalanceChanged>[];
      final updates = repo.updates.listen((update) {
        if (update is SpBalanceChanged) balances.add(update);
      });
      addTearDown(updates.cancel);
      final sub = repo.notifications.listen((_) {});
      addTearDown(sub.cancel);

      final restarting = repo.restartElectrum();
      notifications.add(
        SpNotification.electrumTx(
          kind: CoinSource.sp,
          txid: 'cafe',
          amountSat: BigInt.from(1000),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(ffi.balanceReads, 0);
      expect(balances, isEmpty);

      ffi.restart!.complete();
      await restarting;
      await Future<void>.delayed(Duration.zero);

      expect(ffi.balanceReads, 1);
      expect(balances.single.totalUnified, Sats.fromInt(1000));
    });
  });

  group('teardown bracket', () {
    test('a nested teardown keeps the guard held for the outer one', () {
      final repo = makeRepo(ffi: _FakeFfiDatasource());

      repo.beginTeardown(); // recreate
      repo.beginTeardown(); // revoke, started while the recreate runs
      repo.endTeardown(); // revoke finishes first

      expect(
        repo.teardownInProgress,
        isTrue,
        reason: 'the recreate still holds it, so no self-heal may create',
      );

      repo.endTeardown();

      expect(repo.teardownInProgress, isFalse);
    });

    test('an unbalanced release cannot drive the depth negative', () {
      final repo = makeRepo(ffi: _FakeFfiDatasource());

      repo.endTeardown();
      repo.beginTeardown();

      expect(repo.teardownInProgress, isTrue);
    });
  });

  group('scanOnce and the scanning flag', () {
    Future<(BwkSpAccountRepository, _OpeningFfiDatasource)> open(
      _PendingScanFiles files,
    ) async {
      accountDirOf().createSync();
      final ffi = _OpeningFfiDatasource()..finishOpen.complete();
      final repo = makeRepo(ffi: ffi, files: files);
      expect(await createOn(repo), isA<Ok<void, SpFailure>>());
      addTearDown(repo.dispose);
      return (repo, ffi);
    }

    test('clear excludes new launches and invalidates an older tick', () async {
      final files = _PendingScanFiles();
      final (repo, ffi) = await open(files);
      final arrived = Completer<void>();
      final finish = Completer<void>();
      ffi.onClearScanState = () {
        arrived.complete();
        return finish.future;
      };
      final admission = (
        revision:
            (repo.snapshot() as Ok<SpWallet, SpFailure>).value.scanRevision,
        isAllowed: () => true,
      );

      final clearing = repo.clearScanState();
      await arrived.future;
      try {
        expect(
          await repo.scanOnce(),
          isA<Err<void, SpFailure>>().having(
            (error) => error.failure,
            'failure',
            isA<SpScanBusy>(),
          ),
        );
        expect(
          await repo.scanOnce(automatic: admission),
          isA<Ok<void, SpFailure>>(),
        );
      } finally {
        finish.complete();
      }
      expect(await clearing, isA<Ok<void, SpFailure>>());
      expect(
        await repo.scanOnce(automatic: admission),
        isA<Ok<void, SpFailure>>(),
      );
      expect(ffi.scanStarts, isEmpty);
      expect(await files.readPendingScan(tempDir.path), isNull);
    });

    test(
      'clear leaves an admitted scan and its resume marker intact',
      () async {
        final files = _PendingScanFiles();
        final (repo, ffi) = await open(files);
        final writing = Completer<void>();
        final finish = Completer<void>();
        files.beforeWrite = (_) {
          writing.complete();
          return finish.future;
        };
        final launching = repo.scanOnce(startHeight: 975000);
        await writing.future;
        try {
          expect(
            await repo.clearScanState(),
            isA<Err<void, SpFailure>>().having(
              (error) => error.failure,
              'failure',
              isA<SpScanBusy>(),
            ),
          );
        } finally {
          finish.complete();
        }
        expect(await launching, isA<Ok<void, SpFailure>>());
        expect(ffi.scanStarts, [975000]);
        expect(await files.readPendingScan(tempDir.path), (
          startHeight: 975000,
          isPaused: false,
        ));
      },
    );

    test('stop cancels only after the pause survives on disk', () async {
      final files = _PendingScanFiles();
      final (repo, ffi) = await open(files);
      expect(
        await repo.scanOnce(startHeight: 975000),
        isA<Ok<void, SpFailure>>(),
      );
      files.beforeWrite = (pending) async {
        if (pending?.isPaused == true) {
          throw const FileSystemException('write failed');
        }
      };

      expect(await repo.stopScan(), isA<Err<void, SpFailure>>());
      expect(ffi.stopCalls, 0);
      expect(repo.isScanningCached, isTrue);
      expect(await files.readPendingScan(tempDir.path), (
        startHeight: 975000,
        isPaused: false,
      ));

      files.beforeWrite = null;
      expect(await repo.stopScan(), isA<Ok<void, SpFailure>>());
      expect(ffi.stopCalls, 1);
      expect(await files.readPendingScan(tempDir.path), (
        startHeight: 975000,
        isPaused: true,
      ));
    });

    test(
      'automatic launch rechecks admission after writing its marker',
      () async {
        final files = _PendingScanFiles();
        final (repo, ffi) = await open(files);
        final writing = Completer<void>();
        final finish = Completer<void>();
        files.beforeWrite = (pending) async {
          if (pending == null) return;
          writing.complete();
          await finish.future;
        };
        var allowed = true;
        final launching = repo.scanOnce(
          automatic: (
            revision:
                (repo.snapshot() as Ok<SpWallet, SpFailure>).value.scanRevision,
            isAllowed: () => allowed,
          ),
        );
        await writing.future;
        allowed = false;
        finish.complete();

        expect(await launching, isA<Ok<void, SpFailure>>());
        expect(ffi.scanStarts, isEmpty);
        expect(await files.readPendingScan(tempDir.path), isNull);
      },
    );

    test('a scan cannot launch while server settings are changing', () async {
      final repo = makeRepo(ffi: _FakeFfiDatasource());
      repo.beginTeardown();

      final result = await repo.scanOnce(
        automatic: (revision: 0, isAllowed: () => true),
      );

      expect((result as Err<void, SpFailure>).failure, isA<SpSessionBusy>());
      expect(repo.isScanningCached, isFalse);
    });

    test(
      'native Busy after a terminal event does not stick the flag',
      () async {
        final repo = makeRepo(
          ffi: _FakeFfiDatasource(
            scanOnceError: const SpError.scannerAlreadyRunning(),
          ),
        );

        final result = await repo.scanOnce();

        expect((result as Err<void, SpFailure>).failure, isA<SpScanBusy>());
        expect(repo.isScanningCached, isFalse);
      },
    );

    test('any other failure clears the flag this call set', () async {
      final repo = makeRepo(
        ffi: _FakeFfiDatasource(
          scanOnceError: const SpError.other(message: 'boom'),
        ),
      );

      final result = await repo.scanOnce();

      expect((result as Err<void, SpFailure>).failure, isA<SpUnexpected>());
      expect(repo.isScanningCached, isFalse);
    });

    test('a started scan holds the flag', () async {
      final repo = makeRepo(ffi: _FakeFfiDatasource());

      final result = await repo.scanOnce();

      expect(result, isA<Ok<void, SpFailure>>());
      expect(repo.isScanningCached, isTrue);
    });
  });

  group('restampMissingTimestamps', () {
    test('restamps through the live session', () {
      final ffi = _FakeFfiDatasource();
      final repo = makeRepo(ffi: ffi);

      final result = repo.restampMissingTimestamps();

      expect(result, isA<Ok<void, SpFailure>>());
      expect(ffi.restampCalls, 1);
    });

    test('skips with no live session', () {
      final ffi = _FakeFfiDatasource(session: false);
      final repo = makeRepo(ffi: ffi);

      final result = repo.restampMissingTimestamps();

      expect(result, isA<Ok<void, SpFailure>>());
      expect(ffi.restampCalls, 0);
    });

    test('skips while a scan holds the account lock', () async {
      final ffi = _FakeFfiDatasource();
      final repo = makeRepo(ffi: ffi);
      await repo.scanOnce();

      final result = repo.restampMissingTimestamps();

      expect(result, isA<Ok<void, SpFailure>>());
      expect(ffi.restampCalls, 0);
    });

    test('skips while an electrum restart holds the account lock', () async {
      final ffi = _FakeFfiDatasource()..restart = Completer<void>();
      final repo = makeRepo(ffi: ffi);
      final restarting = repo.restartElectrum();

      final during = repo.restampMissingTimestamps();
      ffi.restart!.complete();
      await restarting;
      final after = repo.restampMissingTimestamps();

      expect(during, isA<Ok<void, SpFailure>>());
      expect(after, isA<Ok<void, SpFailure>>());
      expect(ffi.restampCalls, 1);
    });

    test('maps an FFI throw to a failure', () {
      final repo = makeRepo(
        ffi: _FakeFfiDatasource(
          restampError: const SpError.other(message: 'lock poisoned'),
        ),
      );

      final result = repo.restampMissingTimestamps();

      expect((result as Err<void, SpFailure>).failure, isA<SpUnexpected>());
    });
  });

  group('preparePsbt', () {
    test('asks bwk to keep a change of 600 sats or more', () async {
      final ffi = _FakeFfiDatasource();
      final repo = makeRepo(ffi: ffi);

      final result = await repo.preparePsbt(
        recipients: const [],
        feerateSatVb: BigInt.one,
      );

      expect(result, isA<Ok<SpTxDraft, SpFailure>>());
      expect(ffi.changeDustThreshold, BigInt.from(600));
    });
  });

  group('FFI error mapping', () {
    // Asserted through a real call rather than the mapper in isolation, so the
    // test also pins that the boundary actually routes throws through it.
    Future<SpFailure> failureFromStopScan(Object thrown) async {
      final repo = makeRepo(ffi: _FakeFfiDatasource(stopScanError: thrown));
      return (await repo.stopScan() as Err<void, SpFailure>).failure;
    }

    test('a drifted simulation maps to SpSimulationDrifted', () async {
      final failure = await failureFromStopScan(
        const SpError.simulationDrifted(detail: 'coin abc:0 not found'),
      );

      expect(failure, isA<SpSimulationDrifted>());
      expect(failure.logMessage, contains('abc:0'));
    });

    test('a dispose timeout maps to SpSessionBusy', () async {
      expect(
        await failureFromStopScan(const SpError.disposeTimedOut()),
        isA<SpSessionBusy>(),
      );
    });

    test('a running scanner maps to SpScanBusy', () async {
      expect(
        await failureFromStopScan(const SpError.scannerAlreadyRunning()),
        isA<SpScanBusy>(),
      );
    });

    test('anything else maps to the catch-all', () async {
      expect(
        await failureFromStopScan(const SpError.other(message: 'boom')),
        isA<SpUnexpected>(),
      );
      expect(
        await failureFromStopScan(StateError('not an SpError')),
        isA<SpUnexpected>(),
      );
    });
  });
}
