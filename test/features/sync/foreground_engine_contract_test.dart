import 'dart:async';
import 'dart:io';

import 'package:background_tasks/native_sync.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:electrum/electrum.dart' show ElectrumSyncResult;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart';

final class _Policy implements WalletConnectionPort {
  SyncFailure? failure;
  Future<void>? gate;
  int calls = 0;

  @override
  Future<Result<T, SyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
  }) async {
    calls++;
    await gate;
    final current = failure;
    if (current != null) return Err(current);
    return Ok(
      const SyncCompletion(SyncMode.revealedScripts, Duration.zero) as T,
    );
  }
}

final class _ThrowingPolicy implements WalletConnectionPort {
  @override
  Future<Result<T, SyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
  }) async => throw const FormatException('sensitive error detail');
}

final class _Catalog implements WalletCatalogPort {
  final PublicWalletDescriptor descriptor;

  _Catalog(this.descriptor);

  @override
  Future<Result<PublicWalletDescriptor, SyncFailure>> find(
    WalletKey key,
  ) async => Ok(descriptor);

  @override
  Future<Result<List<PublicWalletDescriptor>, SyncFailure>> list() async =>
      Ok([descriptor]);
}

void main() {
  const id = 'wpkh([aabbccdd/84h/1h/0h])';
  final descriptor = BitcoinWalletDescriptor(
    key: WalletKey(id: id, network: BitcoinNetwork.testnet),
    scriptType: ScriptType.bip84,
    origin: id,
    externalDescriptor: 'wpkh(public)',
    internalDescriptor: 'wpkh(change)',
  );
  late Directory directory;
  late _Policy policy;
  late ElectrumSync engine;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('foreground-engine-');
    log = Logger.replace(directory: directory);
    policy = _Policy();
    engine = ElectrumSync(
      connections: policy,
      documentsDirectory: () async => directory.path,
      readRevision: (_) async => const Err(SyncNotFoundFailure()),
    );
  });

  tearDown(() async {
    await log.flush();
    directory.deleteSync(recursive: true);
  });

  for (final reason in SyncReason.values) {
    test(
      'persists started, finished and failed reason=${reason.name}',
      () async {
        final foreground = ForegroundWalletSynchronization(engine);
        expect(await foreground.execute(descriptor, reason: reason), isA<Ok>());
        policy.failure = const SyncConnectionFailure();
        expect(
          await foreground.execute(descriptor, reason: reason),
          isA<Err<void, SyncFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<SyncConnectionFailure>(),
          ),
        );
        final rows = (await log.readLogs())
            .where((row) => row.contains('Electrum sync '))
            .toList();
        expect(rows.where((row) => row.contains('started')), hasLength(2));
        expect(rows.where((row) => row.contains('finished')), hasLength(1));
        expect(rows.where((row) => row.contains('failed')), hasLength(1));
        expect(rows, everyElement(contains('reason=${reason.name}')));
        expect(rows.join(), isNot(contains(id)));
      },
    );
  }

  test('foreground forwards discovery and initial-scan policy', () async {
    final foreground = ForegroundWalletSynchronization(engine);
    await foreground.execute(descriptor);
    await foreground.execute(descriptor, discover: true);
    await foreground.execute(descriptor, allowInitialScan: false);
    expect(policy.calls, 3);
    final rows = (await log.readLogs())
        .where((row) => row.contains('Electrum sync started '))
        .toList();
    expect(rows, hasLength(3));
    expect(rows[0], contains('discovery=false allow_initial_scan=true'));
    expect(rows[1], contains('discovery=true allow_initial_scan=true'));
    expect(rows[2], contains('discovery=false allow_initial_scan=false'));
  });

  for (final failure in const <SyncFailure>[
    SyncBusyFailure(),
    SyncInitialScanRequiredFailure(),
    SyncNeedsRepairFailure(),
    SyncConnectionFailure(),
  ]) {
    test('foreground retains ${failure.runtimeType} and finishes', () async {
      policy.failure = failure;
      final finished = engine.finished.first;
      final result = await ForegroundWalletSynchronization(engine)
          .execute(descriptor, discover: true, reason: SyncReason.manual);
      expect(
        result,
        isA<Err<void, SyncFailure>>().having(
          (result) => result.failure,
          'failure',
          same(failure),
        ),
      );
      expect((await finished).key, descriptor.key);
    });
  }

  test('busy and deferred scans finish without reporting an outage', () async {
    final results = <ElectrumSyncResult>[];
    final finished = <WalletKey>[];
    final resultSubscription = ElectrumSyncResult.watch(engine.finished)
        .listen(results.add);
    final finishedSubscription = engine.finished.listen(
      (event) => finished.add(event.key),
    );
    addTearDown(() async {
      await resultSubscription.cancel();
      await finishedSubscription.cancel();
    });
    final foreground = ForegroundWalletSynchronization(engine);
    policy.failure = const SyncBusyFailure();
    expect(await foreground.execute(descriptor), isA<Err>());
    await pumpEventQueue();
    expect(results, isEmpty);
    expect(finished, [descriptor.key]);
    policy.failure = const SyncInitialScanRequiredFailure();
    expect(
      await foreground.execute(descriptor, allowInitialScan: false),
      isA<Err>(),
    );
    await pumpEventQueue();
    expect(results, isEmpty);
    expect(finished, [descriptor.key, descriptor.key]);
    policy.failure = const SyncConnectionFailure();
    expect(await foreground.execute(descriptor), isA<Err>());
    await pumpEventQueue();
    expect(results, hasLength(1));
    expect(results.single.success, isFalse);
  });

  test('joined auto and queued discovery keep their own reasons', () async {
    final gate = Completer<void>();
    policy.gate = gate.future;
    final auto = engine.execute(descriptor);
    await pumpEventQueue();
    final pull = engine.execute(descriptor, reason: SyncReason.pull);
    final manual = engine.execute(
      descriptor,
      discover: true,
      reason: SyncReason.manual,
    );
    await pumpEventQueue();
    expect(policy.calls, 1);
    gate.complete();
    await Future.wait([auto, pull, manual]);
    final rows = (await log.readLogs())
        .where((row) => row.contains('Electrum sync '))
        .toList();
    expect(rows, hasLength(4));
    expect(rows.take(2), everyElement(contains('reason=auto')));
    expect(rows.skip(2), everyElement(contains('reason=manual')));
    expect(policy.calls, 2);
  });

  test('background adapter persists its reason and discovery policy', () async {
    final background = BackgroundWalletSyncImpl(
      _Catalog(descriptor),
      engine,
      collectIncoming: false,
    );
    // The policy fixture returns no committed revision.
    expect(
      await background.synchronize(
        descriptor.key,
        allowInitialScan: false,
        discover: true,
      ),
      isA<Err>(),
    );
    final rows = (await log.readLogs())
        .where((row) => row.contains('Electrum sync '))
        .toList();
    expect(rows, hasLength(2));
    expect(rows, everyElement(contains('reason=background')));
    expect(rows, everyElement(contains('headless=true')));
    expect(rows.first, contains('discovery=true'));
  });

  test(
    'unexpected policy failure settles once and bounds diagnostics',
    () async {
      final sync = ElectrumSync(
        connections: _ThrowingPolicy(),
        documentsDirectory: () async => directory.path,
        readRevision: (_) async => const Err(SyncNotFoundFailure()),
      );
      final finished = sync.finished.first;
      final result = await sync.execute(descriptor);
      expect(result, isA<Err<SyncCompletion, SyncFailure>>());
      expect((await finished).result, same(result));
      expect(sync.isSyncing(), isFalse);
      expect(await sync.execute(descriptor), isA<Err>());
      expect(
        (await log.readLogs())
            .where((row) => row.split('\t')[1] == 'SEVERE')
            .map((row) => row.split('\t')[2]),
        ['Electrum sync unexpected failure reason=auto'],
      );
    },
  );
}
