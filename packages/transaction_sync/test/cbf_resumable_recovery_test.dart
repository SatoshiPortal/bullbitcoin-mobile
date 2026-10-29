import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/src/data/bdk/bdk_cbf_node.dart';
import 'package:transaction_sync/src/data/bdk/bdk_cbf_service.dart';
import 'package:transaction_sync/transaction_sync.dart';

enum _Phase { headers, filters, blocks }

enum _Interruption {
  pause,
  ownerDestruction,
  lease,
  overflow,
  tor,
  walletSet,
  stall,
  networkFlaps,
}

final class _PersistedUpdate implements BdkCbfUpdate {
  final int height;
  final List<Uint8List> transactions;
  bool disposed = false;

  _PersistedUpdate(this.height, [this.transactions = const []]);

  @override
  void apply(bdk.Wallet wallet) {
    final hash = bdk.BlockHash.fromString(
      hex: height.toRadixString(16).padLeft(64, '0'),
    );
    try {
      wallet.insertCheckpoint(
        blockId: bdk.BlockId(height: height, hash: hash),
      );
    } finally {
      hash.dispose();
    }
    for (final bytes in transactions) {
      final transaction = bdk.Transaction(transactionBytes: bytes);
      try {
        wallet.applyUnconfirmedTxs(
          unconfirmedTxs: [
            bdk.UnconfirmedTx(tx: transaction, lastSeen: 1720000000),
          ],
        );
      } finally {
        transaction.dispose();
      }
    }
  }

  @override
  void dispose() => disposed = true;
}

final class _RecoveryNode implements BdkCbfReactiveNode {
  final List<String> descriptorIds;
  final queue = Queue<BdkCbfBatch>();
  final infos = Queue<bdk.Info>();
  final received = <_PersistedUpdate>[];
  bool stopping = false;
  bool disposed = false;
  bool expired = false;
  bool overflow = false;
  int polls = 0;

  _RecoveryNode(this.descriptorIds);

  void boundary(
    int height, {
    bool complete = false,
    List<Uint8List> txs = const [],
  }) {
    final updates = <String, BdkCbfUpdate>{};
    for (final id in descriptorIds) {
      final update = _PersistedUpdate(height, txs);
      updates[id] = update;
      received.add(update);
    }
    queue.add(
      BdkCbfBatch(
        updates: updates,
        scannedHeight: height,
        syncedToTip: complete,
      ),
    );
  }

  @override
  Future<SendPort?> prepare() async => null;
  @override
  void run() => infos.add(bdk.SuccessfulHandshakeInfo());
  @override
  void renewLease() {
    if (stopping || expired || overflow) throw bdk.NodeStoppedCbfException();
  }

  @override
  BdkCbfBatch? pollUpdateBatch() {
    polls++;
    return queue.isEmpty ? null : queue.removeFirst();
  }

  @override
  List<bdk.Info> drainInfo() {
    final result = infos.toList();
    infos.clear();
    return result;
  }

  @override
  void drainWarnings() {}
  @override
  bdk.CbfStatus status() => bdk.CbfStatus(
    running: !stopping && !expired && !overflow,
    terminated: isTerminated,
    lastError: overflow ? 'delivery overflow: drain and rebuild' : null,
    infoDropped: 0,
    warningsDropped: 0,
  );
  @override
  bool get isTerminated => stopping || expired || overflow;
  @override
  Future<void> submit(bdk.Transaction transaction) async {}
  @override
  void shutdown() => stopping = true;
  @override
  void dispose() => disposed = true;
}

Future<void> _until(bool Function() condition) async {
  for (var index = 0; index < 400 && !condition(); index++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue);
}

final class _Harness {
  final Directory directory;
  final Duration stallTimeout;
  final Map<String, dynamic> descriptors;
  final coordinator = InMemoryWalletSourceOperationCoordinator();
  final nodes = <_RecoveryNode>[];
  final loaded = <List<int>>[];
  final published = <int>[];
  final progress = <BitcoinSyncProgress>[];
  late SqliteWalletSyncMetadataStore metadata;
  late BdkCbfService service;
  StreamSubscription<BitcoinSyncProgress>? subscription;

  _Harness(this.directory, this.descriptors, this.stallTimeout);

  static Future<_Harness> open(
    Map<String, dynamic> descriptors, {
    Duration stallTimeout = const Duration(minutes: 3),
  }) async {
    final directory = await Directory.systemTemp.createTemp(
      'cbf-resume-policy-',
    );
    final result = _Harness(directory, descriptors, stallTimeout);
    await result._open();
    return result;
  }

  Future<void> _open() async {
    metadata = await SqliteWalletSyncMetadataStore.open(
      databasePath: '${directory.path}/metadata.sqlite',
    );
    service = BdkCbfService(
      metadata: metadata,
      stallTimeout: stallTimeout,
      coordinator: coordinator,
      pollInterval: const Duration(milliseconds: 5),
      joinTimeout: const Duration(milliseconds: 5),
      peerTimeout: const Duration(minutes: 10),
      nodeFactory: (wallets, configuration) {
        final heights = <int>[];
        final ids = <String>[];
        for (final wallet in wallets) {
          final checkpoint = wallet.latestCheckpoint();
          heights.add(checkpoint.height);
          checkpoint.hash.dispose();
          ids.add(wallet.descriptorId(keychain: bdk.KeychainKind.external_));
        }
        loaded.add(heights);
        final node = _RecoveryNode(ids);
        nodes.add(node);
        return node;
      },
      publish: (registration, value, recovery, session) async {
        session.ensureOpen();
        final observation = value.observation;
        published.add(
          int.parse((observation.sourceTip ?? '0').split(':').first),
        );
        return Ok(
          WalletTransactionSyncOutcome(
            WalletTransactionSnapshot(
              key: registration.key,
              revision: published.length,
              contentFingerprint: '${published.length}',
              transactions: observation.transactions,
              observedAt: DateTime.utc(2026, 10, 29),
              lastSuccessfulSyncAt: null,
              sourceKind: registration.sourceKind,
              capabilities: observation.capabilities,
              sourceTip: observation.sourceTip,
              complete: observation.complete,
              evidenceLevel: observation.evidenceLevel,
            ),
          ),
        );
      },
    );
    subscription = service
        .watchBitcoinSyncProgress(registration().key)
        .listen(progress.add);
  }

  WalletSourceRegistration registration({
    bool second = false,
    bool tor = false,
    int? port,
  }) {
    return WalletSourceRegistration.withFingerprint(
      key: WalletNetworkKey(second ? 'second' : 'public', 'bitcoin', 'mainnet'),
      sourceKind: 'bdk_electrum',
      configuration: BdkCbfConfiguration(
        externalPublicDescriptor: (descriptors['external'] as String)
            .replaceAll('/0/*', second ? '/2/*' : '/0/*'),
        internalPublicDescriptor: (descriptors['internal'] as String)
            .replaceAll('/1/*', second ? '/3/*' : '/1/*'),
        isTestnet: false,
        databaseFilePath:
            '${directory.path}/${second ? 'second' : 'public'}.sqlite',
        checkpoint: BitcoinSyncCheckpoint.segwit,
        torRequired: tor,
        socksPort: port,
      ),
    );
  }

  Future<bool> complete() {
    final request = registration();
    return metadata.isCbfDiscoveryComplete(
      request.key,
      (request.configuration as BdkCbfConfiguration).scanPolicyFingerprint,
    );
  }

  T withWallet<T>(T Function(bdk.Wallet wallet) action) {
    final config = registration().configuration as BdkCbfConfiguration;
    final external = bdk.Descriptor(
      descriptor: config.externalPublicDescriptor,
      networkKind: bdk.NetworkKind.main,
    );
    final internal = bdk.Descriptor(
      descriptor: config.internalPublicDescriptor,
      networkKind: bdk.NetworkKind.main,
    );
    final persister = bdk.Persister.newSqlite(path: config.databaseFilePath);
    final wallet = bdk.Wallet.load(
      descriptor: external,
      changeDescriptor: internal,
      persister: persister,
      lookahead: 1000,
    );
    try {
      return action(wallet);
    } finally {
      wallet.dispose();
      persister.dispose();
      external.dispose();
      internal.dispose();
    }
  }

  Map<String, Object?> state() => withWallet((wallet) {
    final checkpoint = wallet.latestCheckpoint();
    final txids = <String>[];
    for (final tx in wallet.transactions()) {
      final id = tx.transaction.computeTxid();
      txids.add(id.toString());
      id.dispose();
      tx.transaction.dispose();
    }
    txids.sort();
    final result = <String, Object?>{
      'height': checkpoint.height,
      'hash': checkpoint.hash.toString(),
      'txids': txids,
      'balance': wallet.balance().total.toSat(),
      'external': wallet.nextDerivationIndex(
        keychain: bdk.KeychainKind.external_,
      ),
      'internal': wallet.nextDerivationIndex(
        keychain: bdk.KeychainKind.internal,
      ),
    };
    checkpoint.hash.dispose();
    return result;
  });

  Uint8List transaction(int nonce) => withWallet((wallet) {
    final address = wallet
        .peekAddress(keychain: bdk.KeychainKind.external_, index: 0)
        .address;
    final script = address.scriptPubkey();
    try {
      final output = script.toBytes();
      final amount = ByteData(8)..setUint64(0, 12345, Endian.little);
      return (BytesBuilder()
            ..add([2, 0, 0, 0, 1])
            ..add([nonce, ...List.filled(31, 0)])
            ..add([255, 255, 255, 255, 0, 255, 255, 255, 255, 1])
            ..add(amount.buffer.asUint8List())
            ..add([output.length])
            ..add(output)
            ..add([0, 0, 0, 0]))
          .toBytes();
    } finally {
      script.dispose();
      address.dispose();
    }
  });

  Future<void> persisted(int height) =>
      _until(() => published.contains(height));

  Future<void> recreateOwner() async {
    await subscription?.cancel();
    await service.dispose();
    await metadata.close();
    await _open();
  }

  Future<void> close() async {
    await subscription?.cancel();
    await service.dispose();
    await metadata.close();
    await directory.delete(recursive: true);
  }
}

void _phase(_RecoveryNode node, _Phase phase) {
  switch (phase) {
    case _Phase.headers:
      node.infos.add(bdk.NewChainHeightInfo(510000));
    case _Phase.filters:
      node.infos.add(
        bdk.FiltersProgressInfo(
          chainHeight: 510000,
          filtersHeight: 500500,
          fraction: 0.5,
        ),
      );
    case _Phase.blocks:
      node.infos.add(bdk.BlockReceivedInfo('public-test-block'));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> descriptors;
  setUpAll(() async {
    final packageFixture = File('test/fixtures/cbf_public_descriptors.json');
    final fixture = packageFixture.existsSync()
        ? packageFixture
        : File(
            'packages/transaction_sync/test/fixtures/cbf_public_descriptors.json',
          );
    descriptors =
        jsonDecode(await fixture.readAsString()) as Map<String, dynamic>;
  });

  for (final phase in _Phase.values) {
    for (final interruption in _Interruption.values) {
      test(
        'persisted recovery matches uninterrupted after ${interruption.name} during ${phase.name}',
        () async {
          final baseline = await _Harness.open(descriptors);
          final interrupted = await _Harness.open(
            descriptors,
            stallTimeout: interruption == _Interruption.stall
                ? const Duration(milliseconds: 800)
                : const Duration(minutes: 3),
          );
          try {
            Future<void> firstBoundary(_Harness harness) async {
              final request = harness.registration(
                tor: interruption == _Interruption.tor,
                port: interruption == _Interruption.tor ? 9050 : null,
              );
              expect(await harness.service.reconcile([request]), isA<Ok>());
              harness.nodes.last.boundary(
                500000,
                txs: [harness.transaction(1)],
              );
              await harness.persisted(500000);
              expect(await harness.complete(), isFalse);
              expect(
                harness.progress.any(
                  (event) => event.phase == BitcoinSyncPhase.done,
                ),
                isFalse,
              );
            }

            await firstBoundary(baseline);
            await firstBoundary(interrupted);
            _phase(interrupted.nodes.last, phase);
            await _until(() => interrupted.nodes.last.infos.isEmpty);
            final initialCount = interrupted.nodes.length;
            var resumeHeight = 500000;
            var expectedNodes = initialCount + 1;
            switch (interruption) {
              case _Interruption.pause:
                interrupted.service.setForegroundActive(false);
                expect(await interrupted.service.pause(), isA<Ok>());
                interrupted.service.setForegroundActive(true);
                expect(
                  await interrupted.service.reconcile([
                    interrupted.registration(),
                  ]),
                  isA<Ok>(),
                );
              case _Interruption.ownerDestruction:
                // Reopen real metadata and wallet SQLite, discarding the entire
                // service and its in-memory recovery/completeness state.
                await interrupted.recreateOwner();
                expect(
                  await interrupted.service.reconcile([
                    interrupted.registration(),
                  ]),
                  isA<Ok>(),
                );
              case _Interruption.lease:
                interrupted.nodes.last.expired = true;
              case _Interruption.overflow:
                for (var offset = 1; offset <= 8; offset++) {
                  final height = 500000 + offset * 1000;
                  interrupted.nodes.last.boundary(height);
                  baseline.nodes.last.boundary(height);
                }
                resumeHeight = 508000;
                interrupted.nodes.last.overflow = true;
                await baseline.persisted(resumeHeight);
              case _Interruption.tor:
                final denied = await interrupted.service.reconcile([
                  interrupted.registration(tor: true),
                ]);
                expect(
                  (denied as Err).failure,
                  isA<CbfTorUnavailableFailure>(),
                );
                expect(interrupted.nodes.length, initialCount);
                expect(
                  await interrupted.service.reconcile([
                    interrupted.registration(tor: true, port: 9150),
                  ]),
                  isA<Ok>(),
                );
              case _Interruption.stall:
                // Peer contact remains recorded, but a missing next filter or
                // block must not leave the running node stuck forever.
                break;
              case _Interruption.networkFlaps:
                expectedNodes = initialCount + 3;
                for (var cycle = 0; cycle < 3; cycle++) {
                  interrupted.service.setForegroundActive(false);
                  expect(
                    await interrupted.service.reconcile([
                      interrupted.registration(),
                    ]),
                    isA<Err>(),
                  );
                  expect(await interrupted.service.pause(), isA<Ok>());
                  interrupted.service.setForegroundActive(true);
                  expect(
                    await interrupted.service.reconcile([
                      interrupted.registration(),
                    ]),
                    isA<Ok>(),
                  );
                }
              case _Interruption.walletSet:
                expect(
                  await interrupted.service.reconcile([
                    interrupted.registration(),
                    interrupted.registration(second: true),
                  ]),
                  isA<Ok>(),
                );
            }
            await _until(() => interrupted.nodes.length == expectedNodes);
            expect(interrupted.nodes.first.disposed, isTrue);
            expect(interrupted.loaded.last.first, resumeHeight);
            expect(await interrupted.complete(), isFalse);
            expect(interrupted.state()['height'], resumeHeight);

            // Replaying an already persisted transaction must be idempotent.
            // The second, distinct transaction proves later boundaries survive.
            for (final harness in [baseline, interrupted]) {
              harness.nodes.last.boundary(
                510000,
                complete: true,
                txs: [harness.transaction(1), harness.transaction(2)],
              );
              await harness.persisted(510000);
              await _until(
                () => harness.progress.any(
                  (event) => event.phase == BitcoinSyncPhase.done,
                ),
              );
              expect(await harness.complete(), isTrue);
              expect(harness.state()['txids'], hasLength(2));
              await _until(
                () => harness.nodes
                    .expand((node) => node.received)
                    .every((update) => update.disposed),
              );
            }
            expect(interrupted.state(), baseline.state());
          } finally {
            await interrupted.close();
            await baseline.close();
          }
        },
      );
    }
  }

  test(
    'pause persists an already-polled batch after its source admission waits',
    () async {
      final harness = await _Harness.open(descriptors);
      final entered = Completer<void>(), release = Completer<void>();
      Future<void>? holder;
      try {
        final request = harness.registration();
        expect(await harness.service.reconcile([request]), isA<Ok>());
        final bytes = harness.transaction(1);
        holder = harness.coordinator.runExclusive(
          const WalletSourceKey('public', 'bitcoin', 'mainnet'),
          (_) async {
            entered.complete();
            await release.future;
          },
        );
        await entered.future;
        final node = harness.nodes.last;
        node.boundary(500000, txs: [bytes]);
        await _until(() => node.queue.isEmpty);
        expect(harness.published, isEmpty);
        harness.service.setForegroundActive(false);
        final pause = Future.wait([
          harness.service.pause(),
          harness.service.pause(),
        ]);
        release.complete();
        await holder;
        expect(await pause, everyElement(isA<Ok>()));
        expect(harness.state()['height'], 500000);
        expect(harness.state()['txids'], hasLength(1));
        expect(await harness.complete(), isFalse);
        expect(node.received.single.disposed, isTrue);
        await harness.recreateOwner();
        expect(await harness.service.reconcile([request]), isA<Ok>());
        expect(harness.loaded.last.single, 500000);
      } finally {
        if (!release.isCompleted) release.complete();
        await holder;
        await harness.close();
      }
    },
  );
}
