import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/cbf_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_progress.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_sync_failure.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

WalletMetadataModel _buildMetadata({String id = '[abcdef12/84h/0h/0h]'}) {
  return WalletMetadataModel(
    id: id,
    masterFingerprint: 'abcdef12',
    xpubFingerprint: '12345678',
    isEncryptedVaultTested: false,
    isPhysicalBackupTested: false,
    xpub: 'xpub-fake',
    externalPublicDescriptor: 'wpkh([abcdef12/84h/0h/0h]xpub-fake/0/*)',
    internalPublicDescriptor: 'wpkh([abcdef12/84h/0h/0h]xpub-fake/1/*)',
    signer: Signer.local,
    isDefault: false,
    bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
  );
}

/// A [CbfNativeSession] fake that never touches `bull_sdk` FFI: info and
/// warning events are pre-scripted, `awaitAndApplyUpdate()` resolves
/// through a caller-controlled [syncCompleter], and the reader loops block
/// on a gate that only [shutdown] opens — mirroring how the real client's
/// `nextInfo`/`nextWarning` only throw `NodeStoppedCbfException` once the
/// node actually stops.
class _FakeCbfNativeSession implements CbfNativeSession {
  final List<bdk.Info> infoEvents = [];
  final List<bdk.Warning> warningEvents = [];
  final syncCompleter = Completer<void>();
  final _stoppedGate = Completer<void>();

  int runCalls = 0;
  int shutdownCalls = 0;
  bool awaitAndApplyUpdateCalled = false;
  bool _isRunning = true;

  /// Records every [applyUnconfirmedTransaction] call's arguments, in
  /// order.
  final appliedUnconfirmedTransactions =
      <({String transaction, bool isPsbt, int lastSeen})>[];

  /// When set, [run] throws this instead of starting the node.
  Object? runError;

  /// When set, [nextInfo]/[nextWarning] throw this instead of the expected
  /// `NodeStoppedCbfException` once [shutdown] takes effect — simulating an
  /// unexpected reader teardown failure.
  Object? teardownError;

  @override
  void run() {
    runCalls++;
    final error = runError;
    if (error != null) throw error;
  }

  @override
  bool isRunning() => _isRunning;

  @override
  Future<bdk.Info> nextInfo() async {
    if (infoEvents.isNotEmpty) return infoEvents.removeAt(0);
    await _stoppedGate.future;
    final error = teardownError;
    if (error != null) throw error;
    throw bdk.NodeStoppedCbfException();
  }

  @override
  Future<bdk.Warning> nextWarning() async {
    if (warningEvents.isNotEmpty) return warningEvents.removeAt(0);
    await _stoppedGate.future;
    throw bdk.NodeStoppedCbfException();
  }

  @override
  Future<void> awaitAndApplyUpdate() async {
    await syncCompleter.future;
    awaitAndApplyUpdateCalled = true;
  }

  @override
  void shutdown() {
    shutdownCalls++;
    _isRunning = false;
    if (!_stoppedGate.isCompleted) _stoppedGate.complete();
  }

  @override
  Future<void> applyUnconfirmedTransaction({
    required String transaction,
    required bool isPsbt,
    required int lastSeen,
  }) async {
    appliedUnconfirmedTransactions.add((
      transaction: transaction,
      isPsbt: isPsbt,
      lastSeen: lastSeen,
    ));
  }
}

void main() {
  group('CbfWalletDatasource.startSync', () {
    test('reports Started, Scanning (with chainHeight/percent), and Completed, '
        'then applies and persists the update', () async {
      final session = _FakeCbfNativeSession()
        ..infoEvents.add(
          bdk.ProgressInfo(chainHeight: 100, filtersDownloadedPercent: 50),
        );
      final datasource = CbfWalletDatasource(
        sessionFactory: (_) async => session,
      );
      final metadata = _buildMetadata();

      final events = <WalletSyncProgress>[];
      final subscription = datasource.watchProgress().listen(events.add);

      final syncFuture = datasource.startSync(metadata: metadata);
      // Let the reader loops drain the single scripted info event before
      // completing the scan.
      await Future<void>.delayed(Duration.zero);
      session.syncCompleter.complete();

      final result = await syncFuture;
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(
        result,
        isA<Ok<CbfSyncOutcome, WalletSyncFailure>>().having(
          (r) => r.value,
          'value',
          CbfSyncOutcome.completed,
        ),
      );
      expect(session.runCalls, 1);
      expect(session.awaitAndApplyUpdateCalled, isTrue);
      expect(session.shutdownCalls, greaterThanOrEqualTo(1));
      expect(
        events.first,
        isA<WalletSyncStarted>().having(
          (e) => e.backend,
          'backend',
          BitcoinSyncBackend.compactBlockFilters,
        ),
      );
      expect(
        events,
        contains(
          isA<WalletSyncScanning>()
              .having((e) => e.chainHeight, 'chainHeight', 100)
              .having((e) => e.scannedPercent, 'scannedPercent', 50.0),
        ),
      );
      expect(events.last, isA<WalletSyncCompleted>());
    });

    test('emits an applyingUpdate stage immediately before awaiting/applying/'
        'persisting the opaque native update, exactly once', () async {
      final session = _FakeCbfNativeSession();
      final datasource = CbfWalletDatasource(
        sessionFactory: (_) async => session,
      );
      final metadata = _buildMetadata();

      final events = <WalletSyncProgress>[];
      final subscription = datasource.watchProgress().listen(events.add);

      final syncFuture = datasource.startSync(metadata: metadata);
      await Future<void>.delayed(Duration.zero);

      // Visible before the opaque update/apply/save call has settled —
      // the fake's awaitAndApplyUpdate() is still blocked on
      // syncCompleter at this point.
      expect(session.awaitAndApplyUpdateCalled, isFalse);
      expect(
        events,
        contains(
          isA<WalletSyncScanning>().having(
            (e) => e.stage,
            'stage',
            WalletSyncScanStage.applyingUpdate,
          ),
        ),
      );

      session.syncCompleter.complete();
      final result = await syncFuture;
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(result, isA<Ok<CbfSyncOutcome, WalletSyncFailure>>());
      // A one-shot signal right before the call, never repeated once the
      // update has settled.
      expect(
        events.whereType<WalletSyncScanning>().where(
          (e) => e.stage == WalletSyncScanStage.applyingUpdate,
        ),
        hasLength(1),
      );
    });

    test('a second call for the same wallet joins the in-flight attempt '
        'instead of starting a second session', () async {
      final session = _FakeCbfNativeSession();
      var factoryCalls = 0;
      final datasource = CbfWalletDatasource(
        sessionFactory: (_) async {
          factoryCalls++;
          return session;
        },
      );
      final metadata = _buildMetadata();

      final first = datasource.startSync(metadata: metadata);
      final second = datasource.startSync(metadata: metadata);
      await Future<void>.delayed(Duration.zero);
      session.syncCompleter.complete();

      final firstResult = await first;
      final secondResult = await second;

      expect(factoryCalls, 1);
      expect(session.runCalls, 1);
      expect(firstResult, isA<Ok<CbfSyncOutcome, WalletSyncFailure>>());
      expect(secondResult, same(firstResult));
    });

    test('a wallet whose previous attempt already settled can start a fresh '
        'session', () async {
      var factoryCalls = 0;
      final datasource = CbfWalletDatasource(
        sessionFactory: (_) async {
          factoryCalls++;
          final session = _FakeCbfNativeSession();
          session.syncCompleter.complete();
          return session;
        },
      );
      final metadata = _buildMetadata();

      await datasource.startSync(metadata: metadata);
      await datasource.startSync(metadata: metadata);

      expect(factoryCalls, 2);
    });

    test('cancelSync is a no-op under the long-lived session policy: the '
        'session keeps running and still settles Completed', () async {
      final session = _FakeCbfNativeSession();
      final datasource = CbfWalletDatasource(
        sessionFactory: (_) async => session,
      );
      final metadata = _buildMetadata();

      final events = <WalletSyncProgress>[];
      final subscription = datasource.watchProgress().listen(events.add);

      final syncFuture = datasource.startSync(metadata: metadata);
      await Future<void>.delayed(Duration.zero);

      await datasource.cancelSync(walletId: metadata.id);
      expect(session.shutdownCalls, 0);

      session.syncCompleter.complete();

      final result = await syncFuture;
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(
        result,
        isA<Ok<CbfSyncOutcome, WalletSyncFailure>>().having(
          (r) => r.value,
          'value',
          CbfSyncOutcome.completed,
        ),
      );
      expect(events, contains(isA<WalletSyncCompleted>()));
      expect(events, isNot(contains(isA<WalletSyncCancelled>())));
    });

    test('cancelSync for a wallet with no active session is a no-op', () async {
      final datasource = CbfWalletDatasource(
        sessionFactory: (_) async => _FakeCbfNativeSession(),
      );

      await expectLater(
        datasource.cancelSync(walletId: 'no-such-wallet'),
        completes,
      );
    });

    test('calling cancelSync repeatedly for the same wallet does not throw and '
        'still never shuts the session down', () async {
      final session = _FakeCbfNativeSession();
      final datasource = CbfWalletDatasource(
        sessionFactory: (_) async => session,
      );
      final metadata = _buildMetadata();

      final syncFuture = datasource.startSync(metadata: metadata);
      await Future<void>.delayed(Duration.zero);

      await datasource.cancelSync(walletId: metadata.id);
      await datasource.cancelSync(walletId: metadata.id);
      expect(session.shutdownCalls, 0);

      session.syncCompleter.complete();
      await syncFuture;
    });

    test('session factory failure maps to WalletSyncCbfFailure and emits a '
        'WalletSyncFailed progress event', () async {
      final datasource = CbfWalletDatasource(
        sessionFactory: (_) async => throw Exception('native init failed'),
      );

      final events = <WalletSyncProgress>[];
      final subscription = datasource.watchProgress().listen(events.add);

      final result = await datasource.startSync(metadata: _buildMetadata());
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(result, isA<Err<CbfSyncOutcome, WalletSyncFailure>>());
      expect(
        (result as Err<CbfSyncOutcome, WalletSyncFailure>).failure,
        isA<WalletSyncCbfFailure>(),
      );
      // Setup fails before Started is ever emitted, so Failed is the only
      // progress event — never a raw exception detail on the event itself.
      expect(events, [
        isA<WalletSyncFailed>().having(
          (e) => e.category,
          'category',
          WalletSyncFailureCategory.compactBlockFilters,
        ),
      ]);
    });

    test('a failure while awaiting/applying/persisting the update maps to '
        'WalletSyncCbfFailure, with no Completed progress event but a '
        'WalletSyncFailed one', () async {
      final session = _FakeCbfNativeSession();
      final datasource = CbfWalletDatasource(
        sessionFactory: (_) async => session,
      );

      final events = <WalletSyncProgress>[];
      final subscription = datasource.watchProgress().listen(events.add);

      final syncFuture = datasource.startSync(metadata: _buildMetadata());
      await Future<void>.delayed(Duration.zero);
      session.syncCompleter.completeError(Exception('sync failed'));

      final result = await syncFuture;
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(result, isA<Err<CbfSyncOutcome, WalletSyncFailure>>());
      expect(
        (result as Err<CbfSyncOutcome, WalletSyncFailure>).failure,
        isA<WalletSyncCbfFailure>(),
      );
      expect(events, isNot(contains(isA<WalletSyncCompleted>())));
      expect(
        events,
        contains(
          isA<WalletSyncFailed>().having(
            (e) => e.category,
            'category',
            WalletSyncFailureCategory.compactBlockFilters,
          ),
        ),
      );
    });

    test('cancelAndWait racing the still-pending session factory shuts the '
        'session down immediately once assigned, never calls run(), and '
        'settles Ok(null) with a Cancelled progress event but no '
        'Started/Completed', () async {
      final session = _FakeCbfNativeSession();
      final sessionFactoryGate = Completer<void>();
      final datasource = CbfWalletDatasource(
        sessionFactory: (_) async {
          await sessionFactoryGate.future;
          return session;
        },
      );
      final metadata = _buildMetadata();

      final events = <WalletSyncProgress>[];
      final subscription = datasource.watchProgress().listen(events.add);

      final syncFuture = datasource.startSync(metadata: metadata);
      // cancelAndWait() (e.g. wallet deletion) runs while the session
      // factory is still pending, so `_CbfSyncAttempt.cancel()` finds no
      // session assigned yet. Not awaited yet: it would otherwise block
      // on `attempt.result`, which cannot settle until the factory below
      // resolves.
      final cancelFuture = datasource.cancelAndWait(walletId: metadata.id);
      await Future<void>.delayed(Duration.zero);
      expect(session.shutdownCalls, 0, reason: 'no session assigned yet');

      // Now let the factory resolve — `_run` must notice `isCancelled` right
      // after assigning the session and shut it down without ever calling
      // run().
      sessionFactoryGate.complete();
      final result = await syncFuture;
      await cancelFuture;
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(result, isA<Ok<CbfSyncOutcome, WalletSyncFailure>>());
      expect(session.runCalls, 0);
      expect(session.shutdownCalls, greaterThanOrEqualTo(1));
      expect(events, [isA<WalletSyncCancelled>()]);
    });

    test(
      'session.run() throwing synchronously maps to WalletSyncCbfFailure '
      'instead of escaping startSync unhandled, and emits WalletSyncFailed',
      () async {
        final session = _FakeCbfNativeSession()
          ..runError = Exception('native run failed');
        final datasource = CbfWalletDatasource(
          sessionFactory: (_) async => session,
        );

        final events = <WalletSyncProgress>[];
        final subscription = datasource.watchProgress().listen(events.add);

        final result = await datasource.startSync(metadata: _buildMetadata());
        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(result, isA<Err<CbfSyncOutcome, WalletSyncFailure>>());
        expect(
          (result as Err<CbfSyncOutcome, WalletSyncFailure>).failure,
          isA<WalletSyncCbfFailure>(),
        );
        expect(
          events,
          contains(
            isA<WalletSyncFailed>().having(
              (e) => e.category,
              'category',
              WalletSyncFailureCategory.compactBlockFilters,
            ),
          ),
        );
      },
    );

    test(
      'an unexpected (non-timeout) reader teardown error maps to '
      'WalletSyncCbfFailure instead of escaping startSync unhandled',
      () async {
        final session = _FakeCbfNativeSession()
          ..teardownError = Exception('reader teardown blew up');
        final datasource = CbfWalletDatasource(
          sessionFactory: (_) async => session,
        );

        final events = <WalletSyncProgress>[];
        final subscription = datasource.watchProgress().listen(events.add);

        final syncFuture = datasource.startSync(metadata: _buildMetadata());
        await Future<void>.delayed(Duration.zero);
        session.syncCompleter.complete();

        final result = await syncFuture;
        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(result, isA<Err<CbfSyncOutcome, WalletSyncFailure>>());
        expect(
          (result as Err<CbfSyncOutcome, WalletSyncFailure>).failure,
          isA<WalletSyncCbfFailure>(),
        );
        expect(
          events,
          contains(
            isA<WalletSyncFailed>().having(
              (e) => e.category,
              'category',
              WalletSyncFailureCategory.compactBlockFilters,
            ),
          ),
        );
      },
    );
  });

  group('CbfWalletDatasource long-lived session policy', () {
    test('a second startSync call for a different wallet while the first is '
        'still active does not disturb the first session, and both settle '
        'Completed', () async {
      final walletOne = _FakeCbfNativeSession();
      final walletTwo = _FakeCbfNativeSession();
      final datasource = CbfWalletDatasource(
        sessionFactory: (metadata) async =>
            metadata.id.contains('wallet-one') ? walletOne : walletTwo,
      );
      final metadataOne = _buildMetadata(id: 'wallet-one');
      final metadataTwo = _buildMetadata(id: 'wallet-two');

      final events = <WalletSyncProgress>[];
      final subscription = datasource.watchProgress().listen(events.add);

      final firstSync = datasource.startSync(metadata: metadataOne);
      final secondSync = datasource.startSync(metadata: metadataTwo);
      await Future<void>.delayed(Duration.zero);

      expect(walletOne.shutdownCalls, 0);
      expect(walletTwo.shutdownCalls, 0);

      walletOne.syncCompleter.complete();
      walletTwo.syncCompleter.complete();
      final results = await Future.wait([firstSync, secondSync]);
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(
        results,
        everyElement(
          isA<Ok<CbfSyncOutcome, WalletSyncFailure>>().having(
            (r) => r.value,
            'value',
            CbfSyncOutcome.completed,
          ),
        ),
      );
      expect(events, isNot(contains(isA<WalletSyncCancelled>())));
    });

    test(
      'this datasource has no Flutter/WidgetsBinding dependency: it can be '
      'constructed and run a full sync with no test binding initialized',
      () async {
        final session = _FakeCbfNativeSession()..syncCompleter.complete();
        final datasource = CbfWalletDatasource(
          sessionFactory: (_) async => session,
        );

        final result = await datasource.startSync(metadata: _buildMetadata());

        expect(result, isA<Ok<CbfSyncOutcome, WalletSyncFailure>>());
      },
    );

    test('dispose() before any startSync call is a safe no-op', () {
      final datasource = CbfWalletDatasource(
        sessionFactory: (_) async => _FakeCbfNativeSession(),
      );

      expect(datasource.dispose, returnsNormally);
    });
  });

  group('CbfWalletDatasource.deleteDataDir', () {
    test('deletes an existing dataDir resolved for the wallet', () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'cbf-datasource-test-',
      );
      addTearDown(() => tempRoot.delete(recursive: true));
      final resolvedDir = Directory('${tempRoot.path}/cbf-data');
      await resolvedDir.create(recursive: true);
      await File('${resolvedDir.path}/headers').writeAsString('placeholder');

      final datasource = CbfWalletDatasource(
        dataDirResolver: (_) async => resolvedDir.path,
      );

      await datasource.deleteDataDir(metadata: _buildMetadata());

      expect(await resolvedDir.exists(), isFalse);
    });

    test('a missing dataDir is not an error', () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'cbf-datasource-test-',
      );
      addTearDown(() => tempRoot.delete(recursive: true));
      final datasource = CbfWalletDatasource(
        dataDirResolver: (_) async => '${tempRoot.path}/never-created',
      );

      await expectLater(
        datasource.deleteDataDir(metadata: _buildMetadata()),
        completes,
      );
    });
  });

  group('CbfWalletDatasource.isActive', () {
    test('a wallet with no attempt is inactive', () {
      final datasource = CbfWalletDatasource(
        sessionFactory: (_) async => _FakeCbfNativeSession(),
      );

      expect(datasource.isActive(walletId: 'no-such-wallet'), isFalse);
    });

    test(
      'is active for the whole span of an in-flight attempt — with no '
      'watchProgress listener ever attached, proving this is read directly '
      'from the attempt registry rather than derived from the progress '
      'stream',
      () async {
        final session = _FakeCbfNativeSession();
        final datasource = CbfWalletDatasource(
          sessionFactory: (_) async => session,
        );
        final metadata = _buildMetadata();

        final syncFuture = datasource.startSync(metadata: metadata);
        await Future<void>.delayed(Duration.zero);

        expect(datasource.isActive(walletId: metadata.id), isTrue);

        session.syncCompleter.complete();
        await syncFuture;

        expect(datasource.isActive(walletId: metadata.id), isFalse);
      },
    );

    test('becomes inactive once cancelAndWait shuts the session down', () async {
      final session = _FakeCbfNativeSession();
      final datasource = CbfWalletDatasource(
        sessionFactory: (_) async => session,
      );
      final metadata = _buildMetadata();

      final syncFuture = datasource.startSync(metadata: metadata);
      await Future<void>.delayed(Duration.zero);
      session.syncCompleter.complete();

      await datasource.cancelAndWait(walletId: metadata.id);
      await syncFuture;

      expect(datasource.isActive(walletId: metadata.id), isFalse);
    });
  });

  group('CbfNativeShutdownGuard', () {
    test('calls the underlying shutdown exactly once', () {
      var calls = 0;
      final guard = CbfNativeShutdownGuard(() => calls++);

      guard();
      guard();
      guard();

      expect(calls, 1);
    });

    test('tolerates NodeStoppedCbfException from a node that already stopped '
        'natively before shutdown was ever requested', () {
      final guard = CbfNativeShutdownGuard(() {
        throw bdk.NodeStoppedCbfException();
      });

      expect(() => guard(), returnsNormally);
    });
  });

  group('CbfWalletDatasource.cancelAndWait', () {
    test('a wallet with no active session resolves immediately', () async {
      final datasource = CbfWalletDatasource(
        sessionFactory: (_) async => _FakeCbfNativeSession(),
      );

      await expectLater(
        datasource.cancelAndWait(walletId: 'no-such-wallet'),
        completes,
      );
    });

    test('cancels the in-flight session and waits for it to settle', () async {
      final session = _FakeCbfNativeSession();
      final datasource = CbfWalletDatasource(
        sessionFactory: (_) async => session,
      );
      final metadata = _buildMetadata();

      final syncFuture = datasource.startSync(metadata: metadata);
      await Future<void>.delayed(Duration.zero);

      session.syncCompleter.complete();
      await expectLater(
        datasource.cancelAndWait(walletId: metadata.id),
        completes,
      );
      expect(session.shutdownCalls, greaterThanOrEqualTo(1));

      await syncFuture;
    });

    test(
      'a session that never settles times out, throws '
      'CbfSessionTeardownTimeoutException, and never swallows the timeout',
      () {
        // Runs under a fake clock so the real cbfCancelAndWaitTimeout bound
        // (20s) doesn't make this test itself slow. The session's
        // awaitAndApplyUpdate() never settles (syncCompleter is never
        // completed), simulating a native update stuck mid-scan even after
        // shutdown() has been requested.
        fakeAsync((async) {
          final session = _FakeCbfNativeSession();
          final datasource = CbfWalletDatasource(
            sessionFactory: (_) async => session,
          );
          // A distinct wallet id: this session's awaitAndApplyUpdate()
          // deliberately never settles, so `BdkFacade.walletLock` for this
          // id is held for good — sharing the default id would leak that
          // permanently-held lock into every later test that also uses
          // the default id (and, since it is a static, process-wide
          // registry, into every other test file run in this isolate).
          final metadata = _buildMetadata(id: 'wallet-that-never-settles');

          unawaited(datasource.startSync(metadata: metadata));
          async.flushMicrotasks();

          Object? thrown;
          unawaited(
            datasource
                .cancelAndWait(walletId: metadata.id)
                .then((_) {}, onError: (e) => thrown = e),
          );
          async.elapse(cbfCancelAndWaitTimeout + const Duration(seconds: 1));

          expect(thrown, isA<CbfSessionTeardownTimeoutException>());
        });
      },
    );
  });

  group('CbfWalletDatasource.applyUnconfirmedTransactionIfActive', () {
    test('no active session -> returns false', () async {
      final datasource = CbfWalletDatasource(
        sessionFactory: (_) async => _FakeCbfNativeSession(),
      );

      final applied = await datasource.applyUnconfirmedTransactionIfActive(
        metadata: _buildMetadata(),
        transaction: 'signed-psbt',
        isPsbt: true,
      );

      expect(applied, isFalse);
    });

    test(
      'an active session -> applies directly to it and returns true',
      () async {
        final session = _FakeCbfNativeSession();
        final datasource = CbfWalletDatasource(
          sessionFactory: (_) async => session,
        );
        final metadata = _buildMetadata();

        final syncFuture = datasource.startSync(metadata: metadata);
        await Future<void>.delayed(Duration.zero);

        final beforeSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final applied = await datasource.applyUnconfirmedTransactionIfActive(
          metadata: metadata,
          transaction: 'signed-psbt',
          isPsbt: true,
        );
        final afterSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        expect(applied, isTrue);
        expect(session.appliedUnconfirmedTransactions, hasLength(1));
        final call = session.appliedUnconfirmedTransactions.single;
        expect(call.transaction, 'signed-psbt');
        expect(call.isPsbt, isTrue);
        expect(call.lastSeen, inInclusiveRange(beforeSec, afterSec));

        session.syncCompleter.complete();
        await syncFuture;
      },
    );
  });

  group('CbfWalletDatasource Tor mid-session cancellation', () {
    test(
      'emitting true on torProxyChangeStream cancels every active session',
      () async {
        final walletOne = _FakeCbfNativeSession();
        final walletTwo = _FakeCbfNativeSession();
        final torProxyController = StreamController<bool>.broadcast();
        final datasource = CbfWalletDatasource(
          sessionFactory: (metadata) async =>
              metadata.id.contains('wallet-one') ? walletOne : walletTwo,
          torProxyChangeStream: torProxyController.stream,
        );
        final metadataOne = _buildMetadata(id: 'wallet-one');
        final metadataTwo = _buildMetadata(id: 'wallet-two');

        final firstSync = datasource.startSync(metadata: metadataOne);
        final secondSync = datasource.startSync(metadata: metadataTwo);
        await Future<void>.delayed(Duration.zero);

        torProxyController.add(true);
        await Future<void>.delayed(Duration.zero);

        expect(walletOne.shutdownCalls, greaterThanOrEqualTo(1));
        expect(walletTwo.shutdownCalls, greaterThanOrEqualTo(1));

        walletOne.syncCompleter.complete();
        walletTwo.syncCompleter.complete();
        await Future.wait([firstSync, secondSync]);
        await torProxyController.close();
      },
    );

    test('emitting false on torProxyChangeStream cancels nothing', () async {
      final session = _FakeCbfNativeSession();
      final torProxyController = StreamController<bool>.broadcast();
      final datasource = CbfWalletDatasource(
        sessionFactory: (_) async => session,
        torProxyChangeStream: torProxyController.stream,
      );
      final metadata = _buildMetadata();

      final syncFuture = datasource.startSync(metadata: metadata);
      await Future<void>.delayed(Duration.zero);

      torProxyController.add(false);
      await Future<void>.delayed(Duration.zero);

      expect(session.shutdownCalls, 0);

      session.syncCompleter.complete();
      await syncFuture;
      await torProxyController.close();
    });

    test('the constructor subscription is background-safe: constructing with '
        'a torProxyChangeStream never touches WidgetsBinding', () {
      final torProxyController = StreamController<bool>.broadcast();
      expect(
        () => CbfWalletDatasource(
          sessionFactory: (_) async => _FakeCbfNativeSession(),
          torProxyChangeStream: torProxyController.stream,
        ),
        returnsNormally,
      );
      torProxyController.close();
    });
  });
}
