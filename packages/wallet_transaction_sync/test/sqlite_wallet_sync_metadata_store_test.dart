import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';
import 'package:wallet_transaction_sync/src/testing/sqlite_wallet_sync_metadata_store_test_support.dart';

void main() {
  late Directory directory;
  late String path;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('wallet-sync-metadata-');
    path = '${directory.path}/metadata.sqlite';
  });

  tearDown(() => directory.deleteSync(recursive: true));

  test('persists registration and metadata across reopen', () async {
    const registration = WalletSourceRegistration(
      key: WalletNetworkKey('wallet', 'bitcoin', 'testnet'),
      sourceKind: 'bdk',
      configurationFingerprint: 'config-hash',
    );
    final store = await SqliteWalletSyncMetadataStore.open(databasePath: path);
    await store.writeRegistration(registration);
    await store.close();
    final reopened = await SqliteWalletSyncMetadataStore.open(
      databasePath: path,
    );
    expect((await reopened.read(registration.key))!.registration, registration);
    expect(
      (await reopened.read(registration.key))!.registration.configuration,
      const OpaqueSourceConfiguration('persisted'),
    );
    await reopened.close();
  });

  test('persists timestamps, success and receipt', () async {
    const registration = WalletSourceRegistration(
      key: WalletNetworkKey('w', 'c', 'n'),
      sourceKind: 's',
      configurationFingerprint: 'f',
    );
    final store = await SqliteWalletSyncMetadataStore.open(databasePath: path);
    final attempted = DateTime.utc(2024, 1, 2, 3, 4, 5);
    final successful = DateTime.utc(2024, 1, 2, 3, 4, 6);
    await store.writeRegistration(registration);
    await store.writeAttempt(registration.key, attempted);
    await store.writeSuccessfulObservation(
      WalletSyncReceipt(
        key: registration.key,
        successfulAt: successful,
        contentFingerprint: 'content',
      ),
    );
    final metadata = await store.read(registration.key);
    expect(metadata!.lastAttemptedSyncAt, attempted);
    expect(metadata.lastSuccessfulSyncAt, successful);
    expect(metadata.contentFingerprint, 'content');
    expect(
      (await store.readReceipt(registration.key))!.successfulAt,
      successful,
    );
    await store.close();
  });

  test('merges a foreground success recorded before registration', () async {
    const key = WalletNetworkKey('wallet', 'bitcoin', 'testnet');
    final at = DateTime.utc(2024, 1, 2);
    final store = await SqliteWalletSyncMetadataStore.open(databasePath: path);
    await store.recordLegacyForegroundSuccess(key, at);
    expect(await store.readLastSuccessfulSyncAt(key), at);
    expect(await store.read(key), isNull);
    await store.writeRegistration(
      const WalletSourceRegistration(
        key: key,
        sourceKind: 'bdk',
        configurationFingerprint: 'configuration-hash',
      ),
    );
    final metadata = await store.read(key);
    expect(metadata!.lastSuccessfulSyncAt, at);
    expect(metadata.contentFingerprint, isNull);
    expect(await store.readReceipt(key), isNull);
    await store.close();
  });

  test(
    'conflicting concurrent registrations retain exactly one identity',
    () async {
      const key = WalletNetworkKey('w', 'c', 'n');
      const first = WalletSourceRegistration(
        key: key,
        sourceKind: 'first',
        configurationFingerprint: 'a',
      );
      const second = WalletSourceRegistration(
        key: key,
        sourceKind: 'second',
        configurationFingerprint: 'b',
      );
      final left = await SqliteWalletSyncMetadataStore.open(databasePath: path);
      final right = await SqliteWalletSyncMetadataStore.open(
        databasePath: path,
      );
      await Future.wait([
        left.writeRegistration(first),
        right.writeRegistration(second),
      ]);
      final stored = await left.read(key);
      expect(stored, isNotNull);
      expect([first, second].contains(stored!.registration), isTrue);
      expect(stored.registration.sourceKind, isNot(equals('')));
      await left.close();
      await right.close();
    },
  );

  test(
    'deletion marker survives reopen and clear removes metadata and receipt',
    () async {
      const key = WalletNetworkKey('w', 'c', 'n');
      const registration = WalletSourceRegistration(
        key: key,
        sourceKind: 's',
        configurationFingerprint: 'f',
      );
      final store = await SqliteWalletSyncMetadataStore.open(
        databasePath: path,
      );
      await store.writeRegistration(registration);
      await store.writeSuccessfulObservation(
        WalletSyncReceipt(
          key: key,
          successfulAt: DateTime.utc(2024),
          contentFingerprint: 'f',
        ),
      );
      await store.writeDeletionMarker(key, WalletDeletionPhase.snapshotEvicted);
      await store.close();
      final reopened = await SqliteWalletSyncMetadataStore.open(
        databasePath: path,
      );
      expect(
        (await reopened.read(key))!.deletionPhase,
        WalletDeletionPhase.snapshotEvicted,
      );
      expect(await reopened.readReceipt(key), isNotNull);
      await reopened.clear(key);
      expect(await reopened.read(key), isNull);
      expect(await reopened.readReceipt(key), isNull);
      await reopened.close();
    },
  );

  test('does not store raw wallet-network identity', () async {
    const key = WalletNetworkKey(
      'wallet-id-sentinel',
      'chain-sentinel',
      'network-sentinel',
    );
    const registration = WalletSourceRegistration(
      key: key,
      sourceKind: 'bdk',
      configurationFingerprint:
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    );
    final store = await SqliteWalletSyncMetadataStore.open(databasePath: path);
    await store.writeRegistration(registration);
    await store.writeSuccessfulObservation(
      WalletSyncReceipt(
        key: key,
        successfulAt: DateTime.utc(2024),
        contentFingerprint:
            'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
      ),
    );
    await store.close();
    final bytes = File(path).readAsBytesSync();
    final text = String.fromCharCodes(Uint8List.fromList(bytes));
    for (final sentinel in [
      'wallet-id-sentinel',
      'chain-sentinel',
      'network-sentinel',
    ]) {
      expect(text, isNot(contains(sentinel)));
    }
  });

  test('rejects a future schema', () async {
    final initial = await SqliteWalletSyncMetadataStore.open(
      databasePath: path,
    );
    await initial.close();
    final database = sqlite3.open(path);
    database.execute('PRAGMA user_version = 3');
    database.dispose();
    expect(
      () => SqliteWalletSyncMetadataStore.open(databasePath: path),
      throwsA(isA<Exception>()),
    );
  });

  test('actor delay does not block the caller isolate heartbeat', () async {
    final store = await SqliteWalletSyncMetadataStoreTestSupport.open(
      databasePath: path,
      actorCommandDelay: const Duration(milliseconds: 120),
    );
    var ticks = 0;
    final timer = Timer.periodic(
      const Duration(milliseconds: 10),
      (_) => ticks++,
    );
    await store.writeRegistration(
      const WalletSourceRegistration(
        key: WalletNetworkKey('heartbeat', 'bitcoin', 'testnet'),
        sourceKind: 'test',
        configurationFingerprint: 'fingerprint',
      ),
    );
    timer.cancel();
    expect(ticks, greaterThan(3));
    await store.close();
  });

  test('actor death fails a pending command and permits reopen', () async {
    final store = await SqliteWalletSyncMetadataStoreTestSupport.open(
      databasePath: path,
      killActorOnCommand: 'attempt',
    );
    final future = store.writeAttempt(
      const WalletNetworkKey('killed', 'bitcoin', 'testnet'),
      DateTime.utc(2024),
    );
    await expectLater(
      future.timeout(const Duration(seconds: 2)),
      throwsA(isA<Exception>()),
    );
    final reopened = await SqliteWalletSyncMetadataStore.open(
      databasePath: path,
    );
    await reopened.close();
  });

  test(
    'observation rollback preserves the previous metadata and receipt',
    () async {
      const key = WalletNetworkKey('rollback', 'bitcoin', 'testnet');
      final initialAt = DateTime.utc(2024, 1, 1);
      final initial = WalletSyncReceipt(
        key: key,
        successfulAt: initialAt,
        contentFingerprint: 'old',
      );
      var store = await SqliteWalletSyncMetadataStore.open(databasePath: path);
      await store.writeRegistration(
        const WalletSourceRegistration(
          key: key,
          sourceKind: 'test',
          configurationFingerprint: 'config',
        ),
      );
      await store.writeSuccessfulObservation(initial);
      await store.close();
      store = await SqliteWalletSyncMetadataStoreTestSupport.open(
        databasePath: path,
        failAfterObservationUpdate: true,
      );
      await expectLater(
        store.writeSuccessfulObservation(
          WalletSyncReceipt(
            key: key,
            successfulAt: DateTime.utc(2025),
            contentFingerprint: 'new',
          ),
        ),
        throwsA(isA<Exception>()),
      );
      await store.close();
      final reopened = await SqliteWalletSyncMetadataStore.open(
        databasePath: path,
      );
      expect((await reopened.read(key))!.lastSuccessfulSyncAt, initialAt);
      expect((await reopened.read(key))!.contentFingerprint, 'old');
      expect((await reopened.readReceipt(key))!.contentFingerprint, 'old');
      await reopened.close();
    },
  );

  test(
    'close rejects new work and terminates after checkpoint failure',
    () async {
      final store = await SqliteWalletSyncMetadataStoreTestSupport.open(
        databasePath: path,
        failCheckpoint: true,
      );
      final close = store.close();
      await expectLater(
        store.writeAttempt(
          const WalletNetworkKey('closed', 'bitcoin', 'testnet'),
          DateTime.utc(2024),
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        close.timeout(const Duration(seconds: 2)),
        throwsA(isA<Exception>()),
      );
      expect(store.actorExitObserved, isTrue);
      await expectLater(store.close(), throwsA(isA<Exception>()));
      final reopened = await SqliteWalletSyncMetadataStore.open(
        databasePath: path,
      );
      await reopened.close();
    },
  );

  test(
    'legacy success merges registered and pending rows monotonically',
    () async {
      const key = WalletNetworkKey('legacy', 'bitcoin', 'testnet');
      const registeredKey = WalletNetworkKey(
        'registered-null',
        'bitcoin',
        'testnet',
      );
      var store = await SqliteWalletSyncMetadataStore.open(databasePath: path);
      await store.recordLegacyForegroundSuccess(key, DateTime.utc(2025));
      await store.close();
      store = await SqliteWalletSyncMetadataStore.open(databasePath: path);
      await store.recordLegacyForegroundSuccess(key, DateTime.utc(2024));
      await store.writeRegistration(
        const WalletSourceRegistration(
          key: key,
          sourceKind: 'test',
          configurationFingerprint: 'config',
        ),
      );
      expect(await store.readLastSuccessfulSyncAt(key), DateTime.utc(2025));
      await store.recordLegacyForegroundSuccess(key, DateTime.utc(2026));
      expect(await store.readLastSuccessfulSyncAt(key), DateTime.utc(2026));
      await store.writeRegistration(
        const WalletSourceRegistration(
          key: registeredKey,
          sourceKind: 'test',
          configurationFingerprint: 'config',
        ),
      );
      await store.recordLegacyForegroundSuccess(
        registeredKey,
        DateTime.utc(2027),
      );
      expect(
        await store.readLastSuccessfulSyncAt(registeredKey),
        DateTime.utc(2027),
      );
      final database = sqlite3.open(path);
      expect(
        database.select(
          'SELECT key_hash FROM wallet_sync_pending_legacy_success',
        ),
        isEmpty,
      );
      database.dispose();
      await store.clear(key);
      await store.clear(registeredKey);
      expect(await store.readLastSuccessfulSyncAt(key), isNull);
      expect(await store.read(key), isNull);
      await store.close();
    },
  );

  test('coordination timeout is sanitized', () async {
    final store = await SqliteWalletSyncMetadataStoreTestSupport.open(
      databasePath: path,
      coordinationAcquisitionTimeout: const Duration(milliseconds: 40),
    );
    final coordination = DurableWalletSourceOperationCoordinator(
      databasePath: '$path.coordination.sqlite',
      acquisitionTimeout: null,
    );
    final gate = const WalletSourceKey(
      '__wallet_sync_metadata__',
      'sqlite',
      'v2',
    );
    final release = Completer<void>();
    final held = coordination.runExclusive(
      gate,
      (_) => release.future,
      timeout: null,
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final error = await store
        .writeRegistration(
          const WalletSourceRegistration(
            key: WalletNetworkKey('timeout', 'bitcoin', 'testnet'),
            sourceKind: 'test',
            configurationFingerprint: 'config',
          ),
        )
        .then<Object?>((_) => null, onError: (Object e) => e);
    expect(error, isA<MetadataCoordinationTimeout>());
    expect(error.toString(), isNot(contains('SQLITE')));
    release.complete();
    await held;
    await store.close();
  });

  test(
    'raw wallet identifiers are absent from metadata and coordination bytes',
    () async {
      const key = WalletNetworkKey(
        'raw-wallet-sentinel',
        'raw-chain',
        'raw-network',
      );
      final store = await SqliteWalletSyncMetadataStore.open(
        databasePath: path,
      );
      await store.writeRegistration(
        const WalletSourceRegistration(
          key: key,
          sourceKind: 'test',
          configurationFingerprint: 'config',
        ),
      );
      await store.close();
      final bytes = String.fromCharCodes(
        Uint8List.fromList(
          File(path).readAsBytesSync() +
              File('$path.coordination.sqlite').readAsBytesSync(),
        ),
      );
      expect(bytes, isNot(contains('raw-wallet-sentinel')));
      expect(bytes, isNot(contains('raw-chain')));
      expect(bytes, isNot(contains('raw-network')));
    },
  );

  test('two subprocesses contend on one metadata database safely', () async {
    final barrier = await Directory.systemTemp.createTemp(
      'wts-process-barrier-',
    );
    final packageConfig = _packageConfigPath();
    final packageRoot =
        Directory.current.path.endsWith('wallet_transaction_sync')
        ? Directory.current.path
        : '${Directory.current.path}/packages/wallet_transaction_sync';
    final script = '$packageRoot/test/support/metadata_subprocess.dart';
    try {
      final processes = await Future.wait([
        Process.start(_dartExecutable(), [
          '--enable-asserts',
          '--packages=$packageConfig',
          script,
          path,
          'a',
          barrier.path,
        ]),
        Process.start(_dartExecutable(), [
          '--enable-asserts',
          '--packages=$packageConfig',
          script,
          path,
          'b',
          barrier.path,
        ]),
      ]);
      for (final role in ['a', 'b']) {
        await _waitForTestFile(File('${barrier.path}/$role-ready'));
      }
      await _waitForTestFile(File('${barrier.path}/a-gate-held'));
      await _waitForTestFile(File('${barrier.path}/b-operation-attempt'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(File('${barrier.path}/b-open').existsSync(), isFalse);
      final release = File('${barrier.path}/a-release')
        ..createSync(exclusive: true);
      release.writeAsStringSync(
        DateTime.now().microsecondsSinceEpoch.toString(),
      );
      final results = await Future.wait(
        processes.map(
          (p) async => ProcessResult(
            p.pid,
            await p.exitCode,
            await p.stdout.transform(SystemEncoding().decoder).join(),
            await p.stderr.transform(SystemEncoding().decoder).join(),
          ),
        ),
      );
      expect(
        results.map((r) => r.exitCode),
        everyElement(0),
        reason: results.map((r) => '${r.exitCode}: ${r.stderr}').join('\n'),
      );
      expect(results.map((r) => r.stderr), everyElement(isEmpty));
      final bAttempt = _marker(barrier, 'b-operation-attempt');
      final aHold = _marker(barrier, 'a-gate-held');
      final aRelease = _marker(barrier, 'a-release');
      final bOpen = _marker(barrier, 'b-open');
      final bComplete = _marker(barrier, 'b-complete');
      expect(aHold, lessThan(bAttempt));
      expect(aHold, lessThan(aRelease));
      expect(aRelease, lessThan(bOpen));
      expect(aRelease, lessThan(bComplete));
      final store = await SqliteWalletSyncMetadataStore.open(
        databasePath: path,
      );
      for (final role in ['a', 'b']) {
        for (var i = 0; i < 8; i++) {
          expect(
            await store.read(
              WalletNetworkKey('$role-$i', 'bitcoin', 'testnet'),
            ),
            isNotNull,
          );
        }
      }
      await store.close();
    } finally {
      await barrier.delete(recursive: true);
    }
  });
}

Future<void> _waitForTestFile(File file) async {
  for (var i = 0; i < 2000; i++) {
    if (file.existsSync()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw TimeoutException('subprocess readiness timed out');
}

int _marker(Directory barrier, String name) =>
    int.parse(File('${barrier.path}/$name').readAsStringSync());

String _packageConfigPath() {
  var directory = Directory.current.absolute;
  while (true) {
    final candidate = File(
      '${directory.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}package_config.json',
    );
    if (candidate.existsSync()) return candidate.path;
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('Unable to locate the Dart package configuration');
    }
    directory = parent;
  }
}

String _dartExecutable() {
  final executable = File(Platform.resolvedExecutable);
  if (executable.uri.pathSegments.last == 'dart') return executable.path;
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final dart = File(
      '$flutterRoot${Platform.pathSeparator}bin${Platform.pathSeparator}cache'
      '${Platform.pathSeparator}dart-sdk${Platform.pathSeparator}bin'
      '${Platform.pathSeparator}dart',
    );
    if (dart.existsSync()) return dart.path;
  }
  var directory = executable.parent;
  while (true) {
    final dart = File(
      '${directory.path}${Platform.pathSeparator}dart-sdk'
      '${Platform.pathSeparator}bin${Platform.pathSeparator}dart',
    );
    if (dart.existsSync()) return dart.path;
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  throw StateError('Unable to locate the Dart executable');
}
