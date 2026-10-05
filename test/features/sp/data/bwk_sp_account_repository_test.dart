import 'dart:io';

import 'package:bb_mobile/features/sp/data/bwk_sp_account_repository.dart';
import 'package:bb_mobile/features/sp/data/datasources/bwk_sp_account_datasource.dart';
import 'package:bb_mobile/features/sp/data/datasources/sp_account_files_datasource.dart';
import 'package:bb_mobile/features/sp/data/sp_storage_names.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

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
  });

  final Object? disposeError;
  final Object? stopScanError;
  final Object? scanOnceError;
  bool session;

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
    final error = stopScanError;
    if (error != null) throw error;
  }

  @override
  Future<void> scanOnce({int? startHeight}) async {
    final error = scanOnceError;
    if (error != null) throw error;
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

  BwkSpAccountRepository makeRepo({BwkSpAccountDatasource? ffi}) =>
      BwkSpAccountRepository(
        ffi: ffi ?? BwkSpAccountDatasource(),
        files: SpAccountFilesDatasource(),
      );

  Directory accountDirOf() =>
      Directory('${tempDir.path}/${SpStorageNames.accountName}');

  Future<Result<void, SpFailure>> createOn(BwkSpAccountRepository repo) =>
      repo.createFromMnemonic(
        network: BitcoinNetwork.mainnet,
        mnemonic: 'abandon abandon abandon',
        blindbitUrl: 'http://blindbit.example',
        electrumUrl: 'tcp://electrum.example:50001',
      );

  group('createFromMnemonic lock clearing', () {
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

  group('createFromMnemonic single-owner guard', () {
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
    test('a refused scan leaves the running scan owning the flag', () async {
      final repo = makeRepo(
        ffi: _FakeFfiDatasource(
          scanOnceError: const SpError.scannerAlreadyRunning(),
        ),
      );

      final result = await repo.scanOnce();

      expect((result as Err<void, SpFailure>).failure, isA<SpScanBusy>());
      expect(
        repo.isScanningCached,
        isTrue,
        reason: 'the winner of the race still has a scan running',
      );
    });

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
