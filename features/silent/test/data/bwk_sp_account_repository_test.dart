import 'dart:async';
import 'dart:io';

import 'package:silent/src/data/bwk_sp_account_repository.dart';
import 'package:silent/src/data/datasources/bwk_sp_account_datasource.dart';
import 'package:silent/src/data/datasources/sp_account_files_datasource.dart';
import 'package:silent/src/data/sp_storage_names.dart';
import 'package:silent/src/domain/entities/sp_tx_draft.dart';
import 'package:silent/src/domain/entities/sp_update.dart';
import 'package:silent/src/domain/entities/sp_wallet.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:rust_bindings/bwk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silent/src/domain/sp_config.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show Secret, SecretFailure;

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
  Object? scanOnceError;
  Object? clearScanError;
  final Object? restampError;
  final Stream<SpNotification> notifications;
  bool session;
  int restampCalls = 0;
  int balanceReads = 0;
  int stopCalls = 0;
  int clearCalls = 0;
  final scanStarts = <int?>[];
  int? lastScannedHeightValue;
  BigInt? changeDustThreshold;
  // Holds restartElectrum open until completed, when set.
  Completer<void>? restart;

  @override
  bool get hasSession => session;

  @override
  String spAddress() => 'sp1test';

  @override
  int? lastScannedHeight() => lastScannedHeightValue;

  @override
  void clearScanState() {
    clearCalls++;
    if (clearScanError case final error?) throw error;
  }

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

class _OpeningDatasource extends _FakeFfiDatasource {
  _OpeningDatasource({super.notifications}) : super(session: false);

  final entered = Completer<void>();
  final releaseOpen = Completer<void>();

  @override
  Future<Result<void, SecretFailure>> createFromSecret({
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
    entered.complete();
    await releaseOpen.future;
    session = true;
    return const Ok(null);
  }

  @override
  void setElectrumUrl(String url) {}

  @override
  Future<void> startElectrum() async {}
}

/// Lets a test hold or fail a marker write, to prove the launch/stop ordering.
class _PendingScanFiles extends SpAccountFilesDatasource {
  Future<void> Function(({int? startHeight, bool isPaused})?)? beforeWrite;
  void Function(({int? startHeight, bool isPaused})?)? afterWrite;

  @override
  Future<void> writePendingScan(
    String dataDir,
    ({int? startHeight, bool isPaused})? pending,
  ) async {
    await beforeWrite?.call(pending);
    await super.writePendingScan(dataDir, pending);
    afterWrite?.call(pending);
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

  Future<Result<void, SilentFailure>> createOn(
    BwkSpAccountRepository repo,
  ) async => repo.createFromSecret(
    network: BitcoinNetwork.mainnet,
    secret: await spSecret(),
    blindbitUrl: 'http://blindbit.example',
    electrumUrl: 'tcp://electrum.example:50001',
  );

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
    test('closing joins an in-flight open and refuses further opens', () async {
      final source = _OpeningDatasource();
      final repo = makeRepo(ffi: source);
      final opening = createOn(repo);
      await source.entered.future;
      final closedUpdates = expectLater(repo.updates, emitsDone);
      final closing = repo.close();
      expect(await createOn(repo), isA<Err<void, SilentFailure>>());
      source.releaseOpen.complete();

      expect(await opening, isA<Ok<void, SilentFailure>>());
      expect(await closing, isA<Ok<void, SilentFailure>>());
      expect(repo.hasSession, isFalse);
      await closedUpdates;
    });

    test('a live session is refused instead of opening a second one', () async {
      final repo = makeRepo(ffi: _FakeFfiDatasource());

      final created = await createOn(repo);

      expect(
        (created as Err<void, SilentFailure>).failure,
        isA<SilentSessionBusy>(),
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
    test(
      'a clean session dispose tears down the notification streams',
      () async {
        final repo = makeRepo(ffi: _FakeFfiDatasource());

        expect(await repo.dispose(), isA<Ok<void, SilentFailure>>());

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
          (disposed as Err<void, SilentFailure>).failure,
          isA<SilentSessionBusy>(),
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

      expect(await repo.dispose(), isA<Ok<void, SilentFailure>>());
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
        if (update is SilentChainTipChanged) tips.add(update.tip);
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
      final balances = <SilentBalanceChanged>[];
      final updates = repo.updates.listen((update) {
        if (update is SilentBalanceChanged) balances.add(update);
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
    test(
      'native Busy does not stick the flag on a scan we did not start',
      () async {
        final repo = makeRepo(
          ffi: _FakeFfiDatasource(
            scanOnceError: const SpError.scannerAlreadyRunning(),
          ),
        );

        final result = await repo.scanOnce();

        expect(
          (result as Err<void, SilentFailure>).failure,
          isA<SilentScanBusy>(),
        );
        expect(
          repo.isScanningCached,
          isFalse,
          reason: 'no scan of ours is running, so the flag must come back down',
        );
      },
    );

    test('a second launch is refused without reaching the FFI', () async {
      final ffi = _FakeFfiDatasource();
      final repo = makeRepo(ffi: ffi);
      expect(await repo.scanOnce(), isA<Ok<void, SilentFailure>>());

      final second = await repo.scanOnce();

      expect(
        (second as Err<void, SilentFailure>).failure,
        isA<SilentScanBusy>(),
      );
      expect(ffi.scanStarts, [null]);
    });

    test('any other failure clears the flag this call set', () async {
      final repo = makeRepo(
        ffi: _FakeFfiDatasource(
          scanOnceError: const SpError.other(message: 'boom'),
        ),
      );

      final result = await repo.scanOnce();

      expect(
        (result as Err<void, SilentFailure>).failure,
        isA<SilentUnexpected>(),
      );
      expect(repo.isScanningCached, isFalse);
    });

    test('a started scan holds the flag', () async {
      final repo = makeRepo(ffi: _FakeFfiDatasource());

      final result = await repo.scanOnce();

      expect(result, isA<Ok<void, SilentFailure>>());
      expect(repo.isScanningCached, isTrue);
    });
  });

  group('pending scan marker', () {
    Future<(BwkSpAccountRepository, _OpeningDatasource)> open(
      SpAccountFilesDatasource files, {
      Stream<SpNotification> notifications = const Stream.empty(),
    }) async {
      accountDirOf().createSync(recursive: true);
      final ffi = _OpeningDatasource(notifications: notifications)
        ..releaseOpen.complete();
      final repo = makeRepo(ffi: ffi, files: files);
      expect(await createOn(repo), isA<Ok<void, SilentFailure>>());
      addTearDown(repo.dispose);
      return (repo, ffi);
    }

    test('a manual scan leaves a resume marker at its start height', () async {
      final files = _PendingScanFiles();
      final (repo, ffi) = await open(files);

      expect(
        await repo.scanOnce(startHeight: 975000),
        isA<Ok<void, SilentFailure>>(),
      );

      expect(ffi.scanStarts, [975000]);
      expect(await files.readPendingScan(tempDir.path), (
        startHeight: 975000,
        isPaused: false,
      ));
    });

    test('a fresh open adopts the marker the last run left', () async {
      final files = _PendingScanFiles();
      accountDirOf().createSync(recursive: true);
      await files.writePendingScan(tempDir.path, (
        startHeight: 900000,
        isPaused: false,
      ));
      final (repo, _) = await open(files);

      final snapshot =
          (repo.snapshot() as Ok<SilentWallet, SilentFailure>).value;

      expect(snapshot.hasPendingScan, isTrue);
      expect(snapshot.isPendingScanPaused, isFalse);
      expect(snapshot.lastScannedHeight, 709656);
    });

    test('a corrupt marker is deleted and the wallet still opens', () async {
      final files = _PendingScanFiles();
      accountDirOf().createSync(recursive: true);
      final marker = File(
        '${accountDirOf().path}/${SpStorageNames.pendingScanFile}',
      )..writeAsStringSync('not a scan');
      final (repo, _) = await open(files);

      expect(marker.existsSync(), isFalse);
      final snapshot =
          (repo.snapshot() as Ok<SilentWallet, SilentFailure>).value;
      expect(snapshot.hasPendingScan, isFalse);
    });

    test('a launch that fails restores the marker it replaced', () async {
      final notifications = StreamController<SpNotification>();
      addTearDown(notifications.close);
      final files = _PendingScanFiles();
      final (repo, ffi) = await open(
        files,
        notifications: notifications.stream,
      );
      expect(
        await repo.scanOnce(startHeight: 900000),
        isA<Ok<void, SilentFailure>>(),
      );
      notifications.add(const SpNotification.scanStopped());
      await Future<void>.delayed(Duration.zero);

      ffi.scanOnceError = const SpError.other(message: 'boom');
      final failed = await repo.scanOnce(startHeight: 910000);

      expect(
        (failed as Err<void, SilentFailure>).failure,
        isA<SilentUnexpected>(),
      );
      expect(repo.isScanningCached, isFalse);
      expect(await files.readPendingScan(tempDir.path), (
        startHeight: 900000,
        isPaused: false,
      ));
    });

    test('stop persists the pause before it stops the scan', () async {
      final files = _PendingScanFiles();
      final (repo, ffi) = await open(files);
      expect(
        await repo.scanOnce(startHeight: 975000),
        isA<Ok<void, SilentFailure>>(),
      );

      expect(await repo.stopScan(), isA<Ok<void, SilentFailure>>());

      expect(ffi.stopCalls, 1);
      expect(await files.readPendingScan(tempDir.path), (
        startHeight: 975000,
        isPaused: true,
      ));
    });

    test(
      'a stop still cancels natively if its pause cannot be persisted',
      () async {
        final files = _PendingScanFiles();
        final (repo, ffi) = await open(files);
        expect(
          await repo.scanOnce(startHeight: 975000),
          isA<Ok<void, SilentFailure>>(),
        );
        files.beforeWrite = (pending) async {
          if (pending?.isPaused == true) {
            throw const FileSystemException('disk full');
          }
        };

        expect(await repo.stopScan(), isA<Err<void, SilentFailure>>());

        expect(ffi.stopCalls, 1);
        expect(
          (repo.snapshot() as Ok<SilentWallet, SilentFailure>)
              .value
              .isPendingScanPaused,
          isTrue,
        );
        expect(await files.readPendingScan(tempDir.path), (
          startHeight: 975000,
          isPaused: false,
        ));
      },
    );

    test('a completed scan drops the marker', () async {
      final notifications = StreamController<SpNotification>();
      addTearDown(notifications.close);
      final files = _PendingScanFiles();
      final (repo, _) = await open(files, notifications: notifications.stream);
      expect(
        await repo.scanOnce(startHeight: 975000),
        isA<Ok<void, SilentFailure>>(),
      );

      final removed = Completer<void>();
      files.afterWrite = (pending) {
        if (pending == null) removed.complete();
      };
      notifications.add(const SpNotification.scanCompleted());
      await removed.future;

      expect(await files.readPendingScan(tempDir.path), isNull);
      final snapshot =
          (repo.snapshot() as Ok<SilentWallet, SilentFailure>).value;
      expect(snapshot.hasPendingScan, isFalse);
    });

    test('clear is refused mid-scan, then drops the marker', () async {
      final notifications = StreamController<SpNotification>();
      addTearDown(notifications.close);
      final files = _PendingScanFiles();
      final (repo, ffi) = await open(
        files,
        notifications: notifications.stream,
      );
      expect(
        await repo.scanOnce(startHeight: 975000),
        isA<Ok<void, SilentFailure>>(),
      );

      expect(await repo.clearScanState(), isA<Err<void, SilentFailure>>());
      expect(ffi.clearCalls, 0);

      notifications.add(const SpNotification.scanStopped());
      await Future<void>.delayed(Duration.zero);

      expect(await repo.clearScanState(), isA<Ok<void, SilentFailure>>());
      expect(ffi.clearCalls, 1);
      expect(await files.readPendingScan(tempDir.path), isNull);
    });
  });

  group('automatic scan admission', () {
    Future<(BwkSpAccountRepository, _OpeningDatasource)> open(
      SpAccountFilesDatasource files, {
      Stream<SpNotification> notifications = const Stream.empty(),
      bool Function()? allowAutomaticScan,
    }) async {
      accountDirOf().createSync(recursive: true);
      final ffi = _OpeningDatasource(notifications: notifications)
        ..releaseOpen.complete();
      final repo = BwkSpAccountRepository(
        ffi: ffi,
        files: files,
        allowAutomaticScan: allowAutomaticScan,
      );
      expect(await createOn(repo), isA<Ok<void, SilentFailure>>());
      addTearDown(repo.dispose);
      return (repo, ffi);
    }

    test('an unchanged decision launches and leaves no marker', () async {
      final files = _PendingScanFiles();
      final (repo, ffi) = await open(files);

      final result = await repo.scanOnce(
        automatic: (revision: repo.scanRevision),
      );

      expect(result, isA<Ok<void, SilentFailure>>());
      expect(ffi.scanStarts, [null]);
      expect(
        await files.readPendingScan(tempDir.path),
        isNull,
        reason: 'an automatic scan never creates a resume marker',
      );
    });

    test('checks live admission again at the native launch boundary', () async {
      var allowed = true;
      final (repo, ffi) = await open(
        _PendingScanFiles(),
        allowAutomaticScan: () => allowed,
      );
      final launch = repo.scanOnce(automatic: (revision: repo.scanRevision));
      allowed = false;
      await launch;
      expect(ffi.scanStarts, isEmpty);
    });

    test('a failed automatic scan is retryable only in its session', () async {
      final events = StreamController<SpNotification>();
      addTearDown(events.close);
      final files = _PendingScanFiles();
      final (repo, _) = await open(files, notifications: events.stream);
      await repo.scanOnce(automatic: (revision: repo.scanRevision));
      events.add(
        const SpNotification.scanFailed(message: 'server unavailable'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(repo.canRetryAutomaticScan, isTrue);
      expect(await files.readPendingScan(tempDir.path), isNull);
      await repo.dispose();
      expect(repo.canRetryAutomaticScan, isFalse);
    });

    test(
      'stopping an automatic scan blocks later launches after reopen',
      () async {
        final files = _PendingScanFiles();
        final (repo, _) = await open(files);
        await repo.scanOnce(automatic: (revision: repo.scanRevision));
        await repo.stopScan();
        await repo.dispose();
        final (reopened, ffi) = await open(files);
        expect(
          await reopened.scanOnce(automatic: (revision: reopened.scanRevision)),
          isA<Ok<void, SilentFailure>>(),
        );
        expect(ffi.scanStarts, isEmpty);
      },
    );

    test('an automatic resume adopts the marker it found', () async {
      final files = _PendingScanFiles();
      accountDirOf().createSync(recursive: true);
      await files.writePendingScan(tempDir.path, (
        startHeight: 975000,
        isPaused: false,
      ));
      final (repo, ffi) = await open(files);

      expect(
        await repo.scanOnce(automatic: (revision: repo.scanRevision)),
        isA<Ok<void, SilentFailure>>(),
      );

      expect(ffi.scanStarts, [975000]);
      expect(await files.readPendingScan(tempDir.path), (
        startHeight: 975000,
        isPaused: false,
      ));
    });

    test('a paused marker refuses an automatic launch', () async {
      final files = _PendingScanFiles();
      accountDirOf().createSync(recursive: true);
      await files.writePendingScan(tempDir.path, (
        startHeight: 975000,
        isPaused: true,
      ));
      final (repo, ffi) = await open(files);

      final result = await repo.scanOnce(
        automatic: (revision: repo.scanRevision),
      );

      expect(result, isA<Ok<void, SilentFailure>>());
      expect(ffi.scanStarts, isEmpty);
    });

    test(
      'an unreadable marker refuses automatic but not manual scan',
      () async {
        final files = _PendingScanFiles();
        accountDirOf().createSync(recursive: true);
        Directory('${accountDirOf().path}/${SpStorageNames.pendingScanFile}')
            .createSync();
        final (repo, ffi) = await open(files);

        await repo.scanOnce(automatic: (revision: repo.scanRevision));
        expect(ffi.scanStarts, isEmpty);

        await repo.scanOnce(startHeight: 975000);
        expect(ffi.scanStarts, [975000]);
      },
    );

    test('a decision made before a stop is refused', () async {
      final files = _PendingScanFiles();
      final (repo, ffi) = await open(files);
      final revision = repo.scanRevision;
      expect(await repo.stopScan(), isA<Ok<void, SilentFailure>>());

      final result = await repo.scanOnce(automatic: (revision: revision));

      expect(result, isA<Ok<void, SilentFailure>>());
      expect(ffi.scanStarts, isEmpty);
      expect(
        repo.scanRevision,
        isNot(revision),
        reason: 'the stop moved the state the decision belonged to',
      );
    });

    test('a decision made before a clear is refused', () async {
      final files = _PendingScanFiles();
      final (repo, ffi) = await open(files);
      final revision = repo.scanRevision;
      expect(await repo.clearScanState(), isA<Ok<void, SilentFailure>>());

      final result = await repo.scanOnce(automatic: (revision: revision));

      expect(result, isA<Ok<void, SilentFailure>>());
      expect(ffi.scanStarts, isEmpty);
    });

    test('a decision made during Clear expires when Clear ends', () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final files = _PendingScanFiles();
      final (repo, ffi) = await open(files);
      files.beforeWrite = (pending) async {
        if (pending != null) return;
        entered.complete();
        await release.future;
      };

      final clear = repo.clearScanState();
      await entered.future;
      final revision = repo.scanRevision;
      release.complete();
      expect(await clear, isA<Ok<void, SilentFailure>>());
      await repo.scanOnce(automatic: (revision: revision));
      expect(ffi.scanStarts, isEmpty);
    });

    test(
      'a newer header tip invalidates a queued automatic decision',
      () async {
        final events = StreamController<SpNotification>();
        addTearDown(events.close);
        final (repo, ffi) = await open(
          _PendingScanFiles(),
          notifications: events.stream,
        );
        final revision = repo.scanRevision;
        events.add(
          const SpNotification.headerProgressStarted(
            phase: HeaderProgressPhase.initialSync,
            start: 900000,
            end: 970181,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        final result = await repo.scanOnce(automatic: (revision: revision));

        expect(result, isA<Ok<void, SilentFailure>>());
        expect(ffi.scanStarts, isEmpty);
      },
    );

    test(
      'failed Clear preserves an existing Stop on disk and in memory',
      () async {
        final files = _PendingScanFiles();
        final (repo, ffi) = await open(files);
        await repo.stopScan();
        ffi.clearScanError = const SpError.other(message: 'clear failed');
        files.beforeWrite = (_) async {
          throw const FileSystemException('disk full');
        };

        expect(await repo.clearScanState(), isA<Err<void, SilentFailure>>());
        await repo.scanOnce(automatic: (revision: repo.scanRevision));

        expect(ffi.clearCalls, 1);
        expect(ffi.scanStarts, isEmpty);
        expect(await files.readPendingScan(tempDir.path), (
          startHeight: null,
          isPaused: true,
        ));
      },
    );
  });

  group('restampMissingTimestamps', () {
    test('restamps through the live session', () {
      final ffi = _FakeFfiDatasource();
      final repo = makeRepo(ffi: ffi);

      final result = repo.restampMissingTimestamps();

      expect(result, isA<Ok<void, SilentFailure>>());
      expect(ffi.restampCalls, 1);
    });

    test('skips with no live session', () {
      final ffi = _FakeFfiDatasource(session: false);
      final repo = makeRepo(ffi: ffi);

      final result = repo.restampMissingTimestamps();

      expect(result, isA<Ok<void, SilentFailure>>());
      expect(ffi.restampCalls, 0);
    });

    test('skips while a scan holds the account lock', () async {
      final ffi = _FakeFfiDatasource();
      final repo = makeRepo(ffi: ffi);
      await repo.scanOnce();

      final result = repo.restampMissingTimestamps();

      expect(result, isA<Ok<void, SilentFailure>>());
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

      expect(during, isA<Ok<void, SilentFailure>>());
      expect(after, isA<Ok<void, SilentFailure>>());
      expect(ffi.restampCalls, 1);
    });

    test('maps an FFI throw to a failure', () {
      final repo = makeRepo(
        ffi: _FakeFfiDatasource(
          restampError: const SpError.other(message: 'lock poisoned'),
        ),
      );

      final result = repo.restampMissingTimestamps();

      expect(
        (result as Err<void, SilentFailure>).failure,
        isA<SilentUnexpected>(),
      );
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

      expect(result, isA<Ok<SilentTxDraft, SilentFailure>>());
      expect(ffi.changeDustThreshold, BigInt.from(600));
    });
  });

  group('FFI error mapping', () {
    // Asserted through a real call rather than the mapper in isolation, so the
    // test also pins that the boundary actually routes throws through it.
    Future<SilentFailure> failureFromStopScan(Object thrown) async {
      final repo = makeRepo(ffi: _FakeFfiDatasource(stopScanError: thrown));
      return (await repo.stopScan() as Err<void, SilentFailure>).failure;
    }

    test('a drifted simulation maps to SilentSimulationDrifted', () async {
      final failure = await failureFromStopScan(
        const SpError.simulationDrifted(detail: 'coin abc:0 not found'),
      );

      expect(failure, isA<SilentSimulationDrifted>());
      expect(failure.logMessage, contains('abc:0'));
    });

    test('a dispose timeout maps to SilentSessionBusy', () async {
      expect(
        await failureFromStopScan(const SpError.disposeTimedOut()),
        isA<SilentSessionBusy>(),
      );
    });

    test('a running scanner maps to SilentScanBusy', () async {
      expect(
        await failureFromStopScan(const SpError.scannerAlreadyRunning()),
        isA<SilentScanBusy>(),
      );
    });

    test('anything else maps to the catch-all', () async {
      expect(
        await failureFromStopScan(const SpError.other(message: 'boom')),
        isA<SilentUnexpected>(),
      );
      expect(
        await failureFromStopScan(StateError('not an SpError')),
        isA<SilentUnexpected>(),
      );
    });
  });
}
