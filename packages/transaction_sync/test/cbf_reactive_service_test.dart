import 'dart:typed_data';
import 'dart:collection';
import 'dart:isolate';
import 'support/fakes.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/src/data/bdk/bdk_cbf_node.dart';
import 'package:transaction_sync/src/data/bdk/bdk_cbf_service.dart';
import 'package:transaction_sync/transaction_sync.dart';

final class _Metadata implements WalletCbfMetadataPort {
  final policies = <String>{};
  bool interruptCompletion = false;
  final relayStates = <WalletNetworkKey, Map<String, CbfRelayState>>{};
  @override
  Future<Map<String, CbfRelayState>> readCbfRelayStates(
    WalletNetworkKey key,
  ) async => Map.of(relayStates[key] ?? {});
  @override
  Future<void> stageCbfTransaction(WalletNetworkKey key, String txid) async {
    relayStates
        .putIfAbsent(key, () => {})
        .putIfAbsent(txid, () => CbfRelayState.notBroadcast);
  }

  @override
  Future<void> writeCbfRelayState(
    WalletNetworkKey key,
    String txid,
    CbfRelayState state,
  ) async {
    final states = relayStates.putIfAbsent(key, () => {});
    if (states[txid] != CbfRelayState.relayed) states[txid] = state;
  }

  @override
  Future<bool> isCbfDiscoveryComplete(
    WalletNetworkKey key,
    String policy,
  ) async => policies.contains('${key.walletId}:$policy');
  @override
  Future<void> completeCbfDiscovery(WalletNetworkKey key, String policy) async {
    if (interruptCompletion) throw const FormatException('process interrupted');
    policies.add('${key.walletId}:$policy');
  }
}

final class _Update implements BdkCbfUpdate {
  final int height;
  bool disposed = false;
  _Update(this.height);
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
  }

  @override
  void dispose() {
    disposed = true;
  }
}

final class _Node implements BdkCbfReactiveNode {
  final batches = Queue<Map<String, BdkCbfUpdate>>();
  bool syncedToTip = true;
  final infos = Queue<bdk.Info>();
  final stopped = Completer<void>();
  final joined = Completer<void>();
  bool noHandshake = false;
  bool evictHandshake = false;
  bool discardInfo = false;
  int infoDropped = 0;
  bool expired = false;
  bool overflow = false;
  @override
  bdk.CbfStatus status() => bdk.CbfStatus(
    running: !expired && !overflow && !stopped.isCompleted,
    terminated: isTerminated,
    lastError: overflow ? 'delivery overflow: drain and rebuild' : null,
    infoDropped: infoDropped,
    warningsDropped: 0,
  );
  bool holdJoin = false;
  bool failRun = false;
  bool disposed = false;
  int calls = 0;
  int submissions = 0;
  final submittedBytes = <Uint8List>[];
  Completer<void>? submitRelease;
  int renewals = 0;
  void Function()? onEmpty;
  @override
  void run() {
    if (failRun) throw const FormatException('startup');
    if (!noHandshake) {
      infos.add(bdk.SuccessfulHandshakeInfo());
    }
    if (evictHandshake) {
      // Match pinned Polling::push_info's 64-entry oldest-first eviction.
      for (var index = 0; index < 64; index++) {
        if (infos.length == 64) {
          infos.removeFirst();
          infoDropped++;
        }
        infos.add(bdk.BlockReceivedInfo('public-block-$index'));
      }
    }
  }

  @override
  Future<SendPort?> prepare() async => null;
  @override
  void renewLease() {
    if (expired || overflow || stopped.isCompleted) {
      throw bdk.NodeStoppedCbfException();
    }
    renewals++;
  }

  @override
  BdkCbfBatch? pollUpdateBatch() {
    calls++;
    if (batches.isEmpty) {
      final callback = onEmpty;
      onEmpty = null;
      callback?.call();
      return null;
    }
    final updates = batches.removeFirst();
    return BdkCbfBatch(
      updates: updates,
      scannedHeight:
          updates.values.whereType<_Update>().firstOrNull?.height ?? 0,
      syncedToTip: syncedToTip,
    );
  }

  @override
  List<bdk.Info> drainInfo() {
    final drained = discardInfo ? <bdk.Info>[] : infos.toList();
    infos.clear();
    return drained;
  }

  @override
  void drainWarnings() {}
  @override
  bool get isTerminated =>
      (expired || overflow || stopped.isCompleted) &&
      (!holdJoin || joined.isCompleted);

  @override
  Future<void> submit(bdk.Transaction transaction) async {
    submissions++;
    submittedBytes.add(transaction.serialize());
    await submitRelease?.future;
  }

  @override
  void shutdown() {
    if (!stopped.isCompleted) {
      stopped.complete();
    }
  }

  @override
  void dispose() {
    disposed = true;
  }
}

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 300 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Map<String, dynamic> descriptors;
  late _Metadata metadata;
  late WalletSourceOperationCoordinator coordinator;
  late BdkCbfService service;
  final nodes = <_Node>[];
  final ids = <String>[];
  final published = <String>[];
  final heights = <int>[];
  final loadedHeights = <int>[];
  var failRun = false;
  var evictHandshake = false;
  var discardInfo = false;

  WalletSourceRegistration registration(
    String id, {
    bool tor = false,
    int? port,
    BitcoinSyncCheckpoint checkpoint = BitcoinSyncCheckpoint.segwit,
  }) => WalletSourceRegistration.withFingerprint(
    key: WalletNetworkKey(id, 'bitcoin', 'mainnet'),
    sourceKind: 'bdk_electrum',
    configuration: BdkCbfConfiguration(
      externalPublicDescriptor: (descriptors['external'] as String).replaceAll(
        '/0/*',
        id == 'a'
            ? '/0/*'
            : id == 'b'
            ? '/2/*'
            : '/4/*',
      ),
      internalPublicDescriptor: (descriptors['internal'] as String).replaceAll(
        '/1/*',
        id == 'a'
            ? '/1/*'
            : id == 'b'
            ? '/3/*'
            : '/5/*',
      ),
      isTestnet: false,
      databaseFilePath: '${directory.path}/$id.sqlite',
      checkpoint: checkpoint,
      torRequired: tor,
      socksPort: port,
    ),
  );

  Uint8List transaction(WalletSourceRegistration registration) {
    final config = registration.configuration as BdkCbfConfiguration;
    final external = bdk.Descriptor(
      descriptor: config.externalPublicDescriptor,
      networkKind: bdk.NetworkKind.main,
    );
    final internal = bdk.Descriptor(
      descriptor: config.internalPublicDescriptor,
      networkKind: bdk.NetworkKind.main,
    );
    final persister = bdk.Persister.newInMemory();
    final wallet = bdk.Wallet(
      descriptor: external,
      changeDescriptor: internal,
      network: bdk.Network.bitcoin,
      persister: persister,
      lookahead: 1000,
    );
    final address = wallet
        .peekAddress(keychain: bdk.KeychainKind.external_, index: 0)
        .address;
    final script = address.scriptPubkey();
    try {
      final output = script.toBytes();
      final bytes = BytesBuilder()
        ..add([2, 0, 0, 0, 1])
        ..add([1, ...List.filled(31, 0)])
        ..add([255, 255, 255, 255, 0, 255, 255, 255, 255, 1]);
      final amount = ByteData(8)..setUint64(0, 12345, Endian.little);
      return (bytes
            ..add(amount.buffer.asUint8List())
            ..add([output.length])
            ..add(output)
            ..add([0, 0, 0, 0]))
          .toBytes();
    } finally {
      script.dispose();
      address.dispose();
      wallet.dispose();
      persister.dispose();
      external.dispose();
      internal.dispose();
    }
  }

  Future<void> expectPending(WalletSourceRegistration registration) async {
    final facade = WalletTransactionSyncFacade.bdkElectrum(
      metadata: RecordingMetadata(),
      coordinator: coordinator,
    );
    try {
      final result = await facade.refreshLocalSnapshot(
        RefreshLocalSnapshotRequest(registration),
      );
      final snapshot =
          (result
                  as Ok<
                    WalletTransactionSyncOutcome,
                    WalletTransactionSyncFailure
                  >)
              .value
              .snapshot;
      expect(snapshot.transactions, hasLength(1));
      expect(snapshot.transactions.single.position, isA<UnconfirmedPosition>());
    } finally {
      await facade.dispose();
    }
  }

  Future<void> reveal(
    WalletSourceRegistration registration,
    bdk.KeychainKind keychain,
    int index,
  ) => coordinator.runExclusive(
    const WalletSourceKey('a', 'bitcoin', 'mainnet'),
    (_) async {
      final config = registration.configuration as BdkCbfConfiguration;
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
        for (final info in wallet.revealAddressesTo(
          keychain: keychain,
          index: index,
        )) {
          info.address.dispose();
        }
        wallet.persist(persister: persister);
      } finally {
        wallet.dispose();
        persister.dispose();
        external.dispose();
        internal.dispose();
      }
    },
  );

  BdkCbfService createService({
    Duration peerTimeout = const Duration(milliseconds: 30),
  }) => BdkCbfService(
    metadata: metadata,
    coordinator: coordinator,
    joinTimeout: const Duration(milliseconds: 5),
    pollInterval: const Duration(milliseconds: 5),
    broadcastTimeout: const Duration(seconds: 1),
    peerTimeout: peerTimeout,
    nodeFactory: (wallets, configuration) {
      ids.clear();
      for (final wallet in wallets) {
        expect(
          wallet.latestCheckpoint().height,
          greaterThanOrEqualTo(BitcoinSyncCheckpoint.segwit.height),
        );
        final checkpoint = wallet.latestCheckpoint();
        loadedHeights.add(checkpoint.height);
        checkpoint.hash.dispose();
        ids.add(wallet.descriptorId(keychain: bdk.KeychainKind.external_));
      }
      final node = _Node()
        ..failRun = failRun
        ..evictHandshake = evictHandshake
        ..discardInfo = discardInfo;
      nodes.add(node);
      return node;
    },
    publish: (registration, value, recovery, session) async {
      session.ensureOpen();
      published.add(registration.key.walletId);
      heights.add(
        int.parse((value.observation.sourceTip ?? '0').split(':').first),
      );
      return Ok(
        WalletTransactionSyncOutcome(
          WalletTransactionSnapshot(
            key: registration.key,
            revision: published.length,
            contentFingerprint: '${published.length}',
            transactions: value.observation.transactions,
            observedAt: DateTime.now(),
            lastSuccessfulSyncAt: DateTime.now(),
            sourceKind: registration.sourceKind,
            capabilities: value.observation.capabilities,
            sourceTip: value.observation.sourceTip,
            complete: true,
            evidenceLevel: value.observation.evidenceLevel,
          ),
        ),
      );
    },
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cbf-reactive-');
    final fixture =
        File('test/fixtures/cbf_public_descriptors.json').existsSync()
        ? File('test/fixtures/cbf_public_descriptors.json')
        : File(
            'packages/transaction_sync/test/fixtures/cbf_public_descriptors.json',
          );
    descriptors =
        jsonDecode(await fixture.readAsString()) as Map<String, dynamic>;
    metadata = _Metadata();
    coordinator = InMemoryWalletSourceOperationCoordinator();
    failRun = false;
    evictHandshake = false;
    discardInfo = false;
    nodes.clear();
    ids.clear();
    published.clear();
    heights.clear();
    loadedHeights.clear();
    service = createService();
  });
  tearDown(() async {
    await service.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'lossy handshake diagnostics cannot block a ready node broadcast',
    () async {
      await service.dispose();
      service = createService(peerTimeout: const Duration(minutes: 10));
      evictHandshake = true;
      final request = registration('a');
      await service.reconcile([request]);
      nodes.single.batches.add({ids.single: _Update(500000)});
      await _until(() => published.length == 1);
      expect(
        await service.synchronize(request),
        isA<Ok<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>(),
      );
      final result = await service.broadcast(request, transaction(request));
      expect(result, isA<Ok<String, WalletTransactionSyncFailure>>());
      expect(nodes.single.submissions, 1);
    },
  );

  test(
    'lost handshakes cannot stop connected peers before a boundary',
    () async {
      evictHandshake = true;
      await service.reconcile([registration('a')]);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(nodes.single.stopped.isCompleted, isFalse);
      expect(metadata.policies, isEmpty);
    },
  );

  test(
    'durable diagnostic overflow proves peer contact after every info is drained',
    () async {
      evictHandshake = true;
      discardInfo = true;
      final request = registration('a');
      await service.reconcile([request]);
      expect(nodes.single.infos, isEmpty);
      expect(nodes.single.infoDropped, 1);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(nodes.single.stopped.isCompleted, isFalse);
      final result = await service.broadcast(request, transaction(request));
      expect(result, isA<Ok<String, WalletTransactionSyncFailure>>());
      expect(nodes.single.submissions, 1);
    },
  );

  test(
    'one multi-wallet node persists checkpoints and publishes repeated boundaries',
    () async {
      expect(
        await service.reconcile([registration('a'), registration('b')]),
        isA<Ok<void, WalletTransactionSyncFailure>>(),
      );
      expect(nodes, hasLength(1));
      expect(ids.toSet(), hasLength(2));
      final first = _Update(500000), second = _Update(500000);
      nodes.single.batches.add({ids[0]: first, ids[1]: second});
      await _until(
        () => published.length == 2 && metadata.policies.length == 2,
      );
      expect(metadata.policies, hasLength(2));
      expect(
        await service.synchronize(registration('b')),
        isA<Ok<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>(),
      );
      nodes.single.batches.add({
        ids[0]: _Update(500001),
        ids[1]: _Update(500001),
      });
      await _until(() => published.length == 4);
      expect(nodes, hasLength(1));
      expect(first.disposed && second.disposed, isTrue);
      expect(nodes.single.calls, greaterThanOrEqualTo(2));
    },
  );

  test('native catch-up never holds a wallet source lock', () async {
    await service.reconcile([registration('a')]);
    var entered = false;
    await coordinator.runExclusive(
      const WalletSourceKey('a', 'bitcoin', 'mainnet'),
      (_) async {
        entered = true;
      },
    );
    expect(entered, isTrue);
    expect(metadata.policies, isEmpty);
    expect(nodes.single.stopped.isCompleted, isFalse);
  });

  test('only a wallet with a persisted update completes discovery', () async {
    await service.reconcile([registration('a'), registration('b')]);
    nodes.single.batches.add({ids[0]: _Update(500000)});
    await _until(() => published.length == 1 && metadata.policies.length == 1);
    expect(metadata.policies, hasLength(1));
    expect(metadata.policies.single, startsWith('a:'));
  });

  test(
    'background first recovery is rejected before node construction',
    () async {
      final result = await service.reconcile([
        registration('a'),
      ], allowInitialScan: false);
      expect(result, isA<Err<void, WalletTransactionSyncFailure>>());
      expect((result as Err).failure, isA<InitialScanRequiredFailure>());
      expect(nodes, isEmpty);
      expect(File('${directory.path}/a.sqlite').existsSync(), isFalse);
    },
  );

  test(
    'wallet set replacement waits for acknowledged native termination',
    () async {
      await service.reconcile([registration('a')]);
      final old = nodes.single..holdJoin = true;
      final result = await service.reconcile([
        registration('a'),
        registration('b'),
      ]);
      expect((result as Err).failure, isA<CbfNodeDidNotStopFailure>());
      expect(nodes, hasLength(1));
      expect(old.disposed, isFalse);
      old.joined.complete();
      await _until(() => old.disposed);
      expect(
        await service.reconcile([registration('a'), registration('b')]),
        isA<Ok<void, WalletTransactionSyncFailure>>(),
      );
      expect(nodes, hasLength(2));
    },
  );

  test(
    'stop during queued preparation prevents any late node startup',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      final locked = coordinator.runExclusive(
        const WalletSourceKey('a', 'bitcoin', 'mainnet'),
        (_) async {
          entered.complete();
          await release.future;
        },
      );
      await entered.future;
      final starting = service.reconcile([registration('a')]);
      await Future<void>.delayed(const Duration(milliseconds: 15));
      final stopping = service.stop();
      release.complete();
      await locked;
      await starting;
      await stopping;
      expect(nodes, isEmpty);
    },
  );

  test(
    'earlier date immediately rebuilds and only the new generation completes its policy',
    () async {
      final later = BitcoinSyncCheckpoint(
        height: 600000,
        blockHash: '0'.padLeft(64, '1'),
      );
      final original = registration('a', checkpoint: later);
      await service.reconcile([original]);
      final old = nodes.single;
      final changed = registration('a');
      await service.reconcile([changed]);
      expect(nodes, hasLength(2));
      expect(old.stopped.isCompleted, isTrue);
      expect(old.disposed, isTrue);
      final policy =
          (changed.configuration as BdkCbfConfiguration).scanPolicyFingerprint;
      expect(
        await metadata.isCbfDiscoveryComplete(changed.key, policy),
        isFalse,
      );
      nodes.last.batches.add({ids.single: _Update(700000)});
      await _until(() => metadata.policies.contains('a:$policy'));
      expect(
        await service.synchronize(changed),
        isA<Ok<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>(),
      );
    },
  );
  test(
    'Tor on off and port changes rebuild and unavailable Tor never builds direct',
    () async {
      await service.reconcile([registration('a')]);
      for (final choice in [(true, 9050), (true, 9150), (false, null)]) {
        final previous = nodes.last;
        final count = nodes.length;
        expect(
          await service.reconcile([
            registration('a', tor: choice.$1, port: choice.$2),
          ]),
          isA<Ok<void, WalletTransactionSyncFailure>>(),
        );
        expect(previous.stopped.isCompleted && previous.disposed, isTrue);
        expect(nodes.length, count + 1);
      }
      final count = nodes.length;
      final result = await service.reconcile([registration('a', tor: true)]);
      expect((result as Err).failure, isA<CbfTorUnavailableFailure>());
      expect(nodes.length, count);
      expect(nodes.last.stopped.isCompleted, isTrue);
    },
  );
  test(
    'failed relay exposes the locked spend as not broadcast after reopen',
    () async {
      final request = registration('a', tor: true);
      final store = await SqliteWalletSyncMetadataStore.open(
        databasePath: '${directory.path}/relay.sqlite',
      );
      final recovering = BdkCbfService(
        nodeFactory: (wallets, configuration) {
          final node = _Node();
          nodes.add(node);
          return node;
        },
        pollInterval: const Duration(milliseconds: 5),
        broadcastTimeout: const Duration(seconds: 1),
        metadata: store,
        coordinator: coordinator,
        publish: (registration, observation, recovery, session) async =>
            const Err(WalletSyncDeferredFailure()),
      );
      final facade = WalletTransactionSyncFacade.bdkElectrum(
        metadata: store,
        coordinator: coordinator,
      );
      try {
        final funding = transaction(request);
        expect(await recovering.persistPending(request, funding), isA<Ok>());
        final nativeFunding = bdk.Transaction(transactionBytes: funding);
        final id = nativeFunding.computeTxid();
        final fundingTxid = id.toString();
        id.dispose();
        nativeFunding.dispose();
        final hash = [
          for (var i = 0; i < fundingTxid.length; i += 2)
            int.parse(fundingTxid.substring(i, i + 2), radix: 16),
        ].reversed.toList();
        final amount = ByteData(8)..setUint64(0, 11345, Endian.little);
        final spend =
            (BytesBuilder()
                  ..add([
                    2,
                    0,
                    0,
                    0,
                    1,
                    ...hash,
                    0,
                    0,
                    0,
                    0,
                    0,
                    255,
                    255,
                    255,
                    255,
                    1,
                  ])
                  ..add(amount.buffer.asUint8List())
                  ..add([22, 0, 20, ...List.filled(20, 0x42), 0, 0, 0, 0]))
                .toBytes();
        final config = request.configuration as BdkCbfConfiguration;
        int unspent() {
          final external = bdk.Descriptor(
            descriptor: config.externalPublicDescriptor,
            networkKind: bdk.NetworkKind.main,
          );
          final internal = bdk.Descriptor(
            descriptor: config.internalPublicDescriptor,
            networkKind: bdk.NetworkKind.main,
          );
          final persister = bdk.Persister.newSqlite(
            path: config.databaseFilePath,
          );
          final wallet = bdk.Wallet.load(
            descriptor: external,
            changeDescriptor: internal,
            persister: persister,
            lookahead: 1000,
          );
          try {
            return wallet.listUnspent().length;
          } finally {
            wallet.dispose();
            persister.dispose();
            external.dispose();
            internal.dispose();
          }
        }

        expect(unspent(), 1);
        expect(
          (await recovering.broadcast(request, spend) as Err).failure,
          isA<CbfTorUnavailableFailure>(),
        );
        expect(
          unspent(),
          0,
          reason: 'the failed local spend still locks its funding input',
        );
        final result = await facade.refreshLocalSnapshot(
          RefreshLocalSnapshotRequest(request),
        );
        final snapshot =
            (result
                    as Ok<
                      WalletTransactionSyncOutcome,
                      WalletTransactionSyncFailure
                    >)
                .value
                .snapshot;
        final outgoing = snapshot.transactions.singleWhere(
          (tx) => tx.amountSats < 0,
        );
        expect(outgoing.position, isA<UnconfirmedPosition>());
        expect(
          outgoing.evidence['cbfNotBroadcast'],
          true,
          reason:
              'the persisted locked spend must expose manual recovery after reopen',
        );
        expect(
          await RetryCbfTransactionUsecase(
            recovering,
          ).execute(request, outgoing.txid),
          isA<Err>(),
        );
        expect(
          nodes,
          isEmpty,
          reason: 'Retry must fail closed while Tor is unavailable',
        );
        expect(
          await CancelCbfTransactionUsecase(
            recovering,
          ).execute(request, outgoing.txid),
          isA<Ok>(),
        );
        expect(
          unspent(),
          1,
          reason: 'Cancel must persist eviction and free the funding input',
        );
        expect(
          (await recovering.broadcast(registration('a'), spend) as Err).failure,
          isA<CbfTransactionNotRecoverableFailure>(),
        );
        expect(
          unspent(),
          1,
          reason:
              'a delayed original send must not revive the canceled transaction',
        );

        final canceled = await facade.refreshLocalSnapshot(
          RefreshLocalSnapshotRequest(request),
        );
        expect(
          (canceled
                  as Ok<
                    WalletTransactionSyncOutcome,
                    WalletTransactionSyncFailure
                  >)
              .value
              .snapshot
              .transactions
              .map((tx) => tx.txid),
          isNot(contains(outgoing.txid)),
        );
        expect(
          await RetryCbfTransactionUsecase(
            recovering,
          ).execute(request, outgoing.txid),
          isA<Err>(),
        );
        expect(nodes, isEmpty);

        Uint8List spendOutput(
          String parent,
          int vout,
          List<(int, List<int>)> outputs,
        ) {
          final hash = [
            for (var i = 0; i < parent.length; i += 2)
              int.parse(parent.substring(i, i + 2), radix: 16),
          ].reversed.toList();
          final index = ByteData(4)..setUint32(0, vout, Endian.little);
          final raw = BytesBuilder()
            ..add([2, 0, 0, 0, 1, ...hash])
            ..add(index.buffer.asUint8List())
            ..add([0, 255, 255, 255, 255, outputs.length]);
          for (final (amount, script) in outputs) {
            final value = ByteData(8)..setUint64(0, amount, Endian.little);
            raw
              ..add(value.buffer.asUint8List())
              ..add([script.length])
              ..add(script);
          }
          return (raw..add([0, 0, 0, 0])).toBytes();
        }

        final fundingNative = bdk.Transaction(transactionBytes: funding);
        final ownScript = fundingNative.output().single.scriptPubkey;
        final parent = spendOutput(fundingTxid, 0, [
          (10000, [0, 20, ...List.filled(20, 0x42)]),
          (1345, ownScript.toBytes()),
        ]);
        ownScript.dispose();
        fundingNative.dispose();
        final parentId =
            (await recovering.persistPending(request, parent)
                    as Ok<String, WalletTransactionSyncFailure>)
                .value;
        final child = spendOutput(parentId, 1, [
          (345, [0, 20, ...List.filled(20, 0x43)]),
        ]);
        final childId =
            (await recovering.persistPending(request, child)
                    as Ok<String, WalletTransactionSyncFailure>)
                .value;
        expect(
          await CancelCbfTransactionUsecase(
            recovering,
          ).execute(request, parentId),
          isA<Err>(),
          reason: 'never report success or silently remove a dependent payment',
        );
        expect(unspent(), 0);
        expect(
          await CancelCbfTransactionUsecase(
            recovering,
          ).execute(request, childId),
          isA<Ok>(),
        );
        expect(
          await CancelCbfTransactionUsecase(
            recovering,
          ).execute(request, parentId),
          isA<Ok>(),
        );
        expect(unspent(), 1);

        // A new send of the exact same bytes can be retried once its chosen
        // route is available; node startup itself never resubmits anything.
        expect(await recovering.persistPending(request, spend), isA<Ok>());
        final available = registration('a');
        expect(await recovering.reconcile([available]), isA<Ok>());
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(nodes.single.submissions, 0);
        expect(
          await RetryCbfTransactionUsecase(
            recovering,
          ).execute(available, outgoing.txid),
          isA<Ok>(),
        );
        expect(nodes.single.submittedBytes.single, orderedEquals(spend));
        final release = Completer<void>();
        nodes.single.submitRelease = release;
        final lateBroadcast = recovering.broadcast(available, spend);
        await _until(() => nodes.single.submissions == 2);
        expect(
          (await lateBroadcast as Err).failure,
          isA<CbfBroadcastNotRelayedFailure>(),
        );
        final lateCancel = CancelCbfTransactionUsecase(
          recovering,
        ).execute(available, outgoing.txid);
        release.complete();
        expect(await lateCancel, isA<Err>());
        expect(
          unspent(),
          0,
          reason: 'a late acknowledgement must never release relayed inputs',
        );

        expect(
          (await store.readCbfRelayStates(request.key))[outgoing.txid],
          CbfRelayState.relayed,
        );
        expect(
          await CancelCbfTransactionUsecase(
            recovering,
          ).execute(available, outgoing.txid),
          isA<Err>(),
        );
        await recovering.persistPending(available, spend);
        expect(
          (await store.readCbfRelayStates(request.key))[outgoing.txid],
          CbfRelayState.relayed,
        );
        final relayed = await facade.refreshLocalSnapshot(
          RefreshLocalSnapshotRequest(available),
        );
        expect(
          (relayed
                  as Ok<
                    WalletTransactionSyncOutcome,
                    WalletTransactionSyncFailure
                  >)
              .value
              .snapshot
              .transactions
              .singleWhere((tx) => tx.txid == outgoing.txid)
              .isNotBroadcast,
          isFalse,
        );
      } finally {
        await facade.dispose();
        await recovering.dispose();
        await store.close();
      }
    },
  );

  test(
    'broadcast reuses the running node during recovery and persists pending first',
    () async {
      final request = registration('a');
      await service.reconcile([request]);
      final result = await service.broadcast(request, transaction(request));
      expect(result, isA<Ok<String, WalletTransactionSyncFailure>>());
      expect(nodes, hasLength(1));
      expect(nodes.single.submissions, 1);
      expect(nodes.single.stopped.isCompleted, isFalse);
      expect(metadata.policies, isEmpty);
      await expectPending(request);
    },
  );

  test(
    'a caller deadline prevents submission after a delayed local notification',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      final node = _Node();
      var notifications = 0;
      final delayed = BdkCbfService(
        metadata: metadata,
        coordinator: coordinator,
        broadcastTimeout: const Duration(milliseconds: 500),
        pollInterval: const Duration(milliseconds: 5),
        nodeFactory: (_, _) => node,
        onTransactionChanged: (_) async {
          if (notifications++ == 0) {
            entered.complete();
            await release.future;
          }
        },
        publish: (_, _, _, _) async => const Err(WalletSyncDeferredFailure()),
      );
      final request = registration('a');
      try {
        expect(await delayed.reconcile([request]), isA<Ok>());
        final broadcast = delayed.broadcast(request, transaction(request));
        await entered.future;
        expect(
          (await broadcast as Err).failure,
          isA<CbfBroadcastNotRelayedFailure>(),
        );
        expect(node.submissions, 0);
        release.complete();
        await delayed.dispose();
        expect(
          node.submissions,
          0,
          reason:
              'a timed-out send cannot start native relay after its deadline',
        );
      } finally {
        if (!release.isCompleted) release.complete();
        await delayed.dispose();
      }
    },
  );

  test(
    'no-peer timeout releases recovery admission without stopping the node',
    () async {
      final node = _Node()..noHandshake = true;
      final isolated = BdkCbfService(
        metadata: metadata,
        coordinator: coordinator,
        broadcastTimeout: const Duration(milliseconds: 500),
        pollInterval: const Duration(milliseconds: 5),
        nodeFactory: (_, _) => node,
        publish: (_, _, _, _) async => const Err(WalletSyncDeferredFailure()),
      );
      final request = registration('a');
      try {
        expect(await isolated.reconcile([request]), isA<Ok>());
        expect(
          (await isolated.broadcast(request, transaction(request)) as Err)
              .failure,
          isA<CbfBroadcastNotRelayedFailure>(),
        );
        // A local staging operation uses the same transaction gate as Cancel.
        // It must be admitted immediately once an attempt with no submission
        // has expired, rather than waiting for the ten-minute peer timeout.
        final nextLocalAction = isolated.persistPending(
          request,
          transaction(request),
        );
        await expectLater(
          nextLocalAction.timeout(const Duration(seconds: 1)),
          completes,
        );
        expect(node.stopped.isCompleted, isFalse);
        expect(node.submissions, 0);
      } finally {
        await isolated.dispose();
      }
    },
  );

  test(
    'broadcast timeout keeps pending without blocking a source read',
    () async {
      final request = registration('a');
      await service.reconcile([request]);
      final release = Completer<void>();
      nodes.single.submitRelease = release;
      final broadcast = service.broadcast(request, transaction(request));
      await _until(() => nodes.single.submissions == 1);
      await coordinator.runExclusive(
        const WalletSourceKey('a', 'bitcoin', 'mainnet'),
        (_) async {},
      );
      final result = await broadcast;
      expect((result as Err).failure, isA<CbfBroadcastNotRelayedFailure>());
      await expectPending(request);
      release.complete();
    },
  );

  test(
    'broadcast saves pending before an unavailable Tor route refuses a node',
    () async {
      final request = registration('a', tor: true);
      final result = await service.broadcast(request, transaction(request));
      expect((result as Err).failure, isA<CbfTorUnavailableFailure>());
      expect(nodes, isEmpty);
      await expectPending(request);
    },
  );
  test(
    'suspending foreground prevents a later broadcast from starting a node',
    () async {
      final request = registration('a');
      final bytes = transaction(request);
      service.setForegroundActive(false);
      final result = await service.broadcast(request, bytes);
      expect(result, isA<Err<String, WalletTransactionSyncFailure>>());
      expect(nodes, isEmpty);
    },
  );
  test(
    'one bounded background node catches up all warm wallets and skips only first recoveries',
    () async {
      final a = registration('a'), b = registration('b'), c = registration('c');
      await service.reconcile([a, b]);
      nodes.single.batches.add({
        ids[0]: _Update(500000),
        ids[1]: _Update(500000),
      });
      await _until(() => metadata.policies.length == 2);
      await service.stop();
      nodes.clear();
      published.clear();
      final batch = service.catchUp([
        a,
        b,
        c,
      ], DateTime.now().toUtc().add(const Duration(seconds: 5)));
      await _until(() => nodes.isNotEmpty);
      expect(nodes, hasLength(1));
      expect(ids, hasLength(2));
      nodes.single.batches.add({
        ids[0]: _Update(500001),
        ids[1]: _Update(500001),
      });
      final results = await batch;
      expect(
        results[a.key],
        isA<Ok<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>(),
      );
      expect(
        results[b.key],
        isA<Ok<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>(),
      );
      expect(
        (results[c.key] as Err).failure,
        isA<InitialScanRequiredFailure>(),
      );
      expect(
        File(
          (c.configuration as BdkCbfConfiguration).databaseFilePath,
        ).existsSync(),
        isFalse,
      );
      expect(nodes.single.stopped.isCompleted && nodes.single.disposed, isTrue);
      expect(published, ['a', 'b']);
    },
  );
  test(
    'one corrupt warm store cannot prevent another wallet background catch-up',
    () async {
      final a = registration('a'), b = registration('b');
      await service.reconcile([a, b]);
      nodes.single.batches.add({
        ids[0]: _Update(500000),
        ids[1]: _Update(500000),
      });
      await _until(() => metadata.policies.length == 2);
      await service.stop();
      nodes.clear();
      await coordinator.runExclusive(
        const WalletSourceKey('b', 'bitcoin', 'mainnet'),
        (_) => File(
          (b.configuration as BdkCbfConfiguration).databaseFilePath,
        ).writeAsString('invalid sqlite'),
      );
      final run = service.catchUp([
        a,
        b,
      ], DateTime.now().toUtc().add(const Duration(seconds: 5)));
      await _until(() => nodes.isNotEmpty);
      expect(ids, hasLength(1));
      nodes.single.batches.add({ids.single: _Update(500001)});
      final results = await run;
      expect(
        results[a.key],
        isA<Ok<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>(),
      );
      expect((results[b.key] as Err).failure, isA<SourceStorageFailure>());
      expect(nodes.single.disposed, isTrue);
    },
  );
  test(
    'an established peer keeps a long recovery alive beyond discovery timeout',
    () async {
      await service.reconcile([registration('a')]);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(nodes.single.stopped.isCompleted, isFalse);
      expect(metadata.policies, isEmpty);
    },
  );

  test(
    'drained diagnostics report progress without completing discovery',
    () async {
      final request = registration('a');
      await service.reconcile([request]);
      nodes.single.infos.add(bdk.SuccessfulHandshakeInfo());
      nodes.single.infos.add(
        bdk.FiltersProgressInfo(
          chainHeight: 500000,
          filtersHeight: 490000,
          fraction: 0.5,
        ),
      );
      final progress = await service
          .watchBitcoinSyncProgress(request.key)
          .firstWhere((value) => value.reachedHeight == 490000);
      expect(progress.phase, BitcoinSyncPhase.checkingBlocks);
      expect(metadata.policies, isEmpty);
    },
  );

  test(
    'a completion marker cannot authorize a replacement store at genesis',
    () async {
      final request = registration('a');
      await service.persistPending(request, transaction(request));
      await metadata.completeCbfDiscovery(
        request.key,
        (request.configuration as BdkCbfConfiguration).scanPolicyFingerprint,
      );
      final result = await service.catchUp([
        request,
      ], DateTime.now().toUtc().add(const Duration(seconds: 1)));
      expect(
        (result[request.key] as Err).failure,
        isA<InitialScanRequiredFailure>(),
      );
      expect(nodes, isEmpty);
      await expectPending(request);
    },
  );

  test(
    'transport preserves BDK identity while a birthday changes scan policy',
    () {
      final cbf = registration('a').configuration as BdkCbfConfiguration;
      final electrum = BdkElectrumConfiguration(
        externalPublicDescriptor: cbf.externalPublicDescriptor,
        internalPublicDescriptor: cbf.internalPublicDescriptor,
        isTestnet: false,
        electrumUrls: const ['tcp://unused'],
        stopGap: 25,
        validateDomain: true,
        databaseFilePath: cbf.databaseFilePath,
      );
      expect(cbf.fingerprint, electrum.fingerprint);
      final earlier =
          registration(
                'a',
                checkpoint: BitcoinSyncCheckpoint.genesis(
                  BitcoinNetwork.mainnet,
                ),
              ).configuration
              as BdkCbfConfiguration;
      expect(cbf.scanPolicyFingerprint, isNot(earlier.scanPolicyFingerprint));
    },
  );
  test(
    'startup failure shuts down and joins the partially constructed node',
    () async {
      failRun = true;
      final result = await service.reconcile([registration('a')]);
      expect((result as Err).failure, isA<SourceStorageFailure>());
      expect(nodes.single.stopped.isCompleted, isTrue);
      expect(nodes.single.disposed, isTrue);
    },
  );
  test(
    'rebuilding a node clears the previous generation peer and tip counters',
    () async {
      final request = registration('a');
      final events = <BitcoinSyncProgress>[];
      final subscription = service
          .watchBitcoinSyncProgress(request.key)
          .listen(events.add);
      await service.reconcile([request]);
      nodes.single.batches.add({ids.single: _Update(500000)});
      await _until(
        () =>
            metadata.policies.length == 1 &&
            events.any((event) => event.phase == BitcoinSyncPhase.done),
      );
      final oldId = events.last.operationId;
      await service.reconcile([registration('a', tor: true, port: 9050)]);
      await _until(() => events.any((event) => event.operationId != oldId));
      final fresh = events.firstWhere((event) => event.operationId != oldId);
      expect(fresh.reachedHeight, 500000);
      expect(fresh.targetHeight, isNull);
      expect(fresh.connectedPeers, isNull);
      await subscription.cancel();
    },
  );
  test(
    'cold broadcast deadline cannot limit a later foreground recovery',
    () async {
      final request = registration('a');
      expect(
        await service.broadcast(request, transaction(request)),
        isA<Ok<String, WalletTransactionSyncFailure>>(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final synchronization = service.synchronize(request);
      nodes.single.batches.add({ids.single: _Update(500000)});
      expect(
        await synchronization,
        isA<Ok<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>(),
      );
      expect(nodes, hasLength(1));
    },
  );
  for (final keychain in [
    bdk.KeychainKind.external_,
    bdk.KeychainKind.internal,
  ]) {
    test(
      'scripts outside the captured $keychain window rebuild the node',
      () async {
        final request = registration('a');
        await service.reconcile([request]);
        await reveal(request, keychain, 999);
        await service.reconcile([request]);
        expect(nodes, hasLength(1));
        await reveal(request, keychain, 1000);
        await service.reconcile([request]);
        expect(nodes, hasLength(2));
        expect(nodes.first.disposed, isTrue);
      },
    );
  }
  test(
    'interrupted recovery resumes its persisted boundary before tip',
    () async {
      final request = registration('a');
      // A process interruption between wallet commit and completion must keep
      // the committed chain available to the next owner.
      metadata.interruptCompletion = true;
      await service.reconcile([request]);
      nodes.single.batches.add({ids.single: _Update(482000)});
      await _until(() => published.length == 1);
      await service.stop();
      await service.dispose();
      metadata.interruptCompletion = false;
      service = createService();
      await service.reconcile([request]);
      expect(
        loadedHeights.last,
        482000,
        reason: 'an incomplete recovery must resume the durable checkpoint',
      );
      nodes.last.batches.add({ids.single: _Update(500000)});
      await _until(() => metadata.policies.length == 1);
      expect(heights.last, 500000);
    },
  );

  for (final keychain in [
    bdk.KeychainKind.external_,
    bdk.KeychainKind.internal,
  ]) {
    test(
      'recovery script coverage rebuild for $keychain preserves its cursor and new window',
      () async {
        final request = registration('a');
        await service.reconcile([request]);
        nodes.single.syncedToTip = false;
        nodes.single.batches.add({ids.single: _Update(500000)});
        await _until(() => published.length == 1);
        await reveal(request, keychain, 1000);
        expect(await service.ensureScriptCoverage(request.key), isA<Ok>());
        expect(nodes, hasLength(2));
        expect(loadedHeights.last, 500000);
        expect(await service.ensureScriptCoverage(request.key), isA<Ok>());
        expect(nodes, hasLength(2));
        expect(metadata.policies, isEmpty);
      },
    );
  }

  test(
    'a missing source store cannot inherit an advanced recovery cursor',
    () async {
      final request = registration('a');
      await service.reconcile([request]);
      nodes.single.syncedToTip = false;
      nodes.single.batches.add({ids.single: _Update(500000)});
      await _until(() => published.length == 1);
      await service.stop();
      await File(
        (request.configuration as BdkCbfConfiguration).databaseFilePath,
      ).delete();
      expect(await service.reconcile([request]), isA<Ok>());
      expect(loadedHeights.last, BitcoinSyncCheckpoint.segwit.height);
      expect(metadata.policies, isEmpty);
    },
  );

  test(
    'expired lease rebuilds from the last persisted wallet checkpoint',
    () async {
      await service.reconcile([registration('a')]);
      nodes.single.batches.add({ids.single: _Update(500000)});
      await _until(() => published.length == 1);
      nodes.single.expired = true;
      await _until(() => nodes.length == 2);
      expect(nodes.first.disposed, isTrue);
      expect(loadedHeights.last, 500000);
      expect(metadata.policies, hasLength(1));
    },
  );
  test('overflow drains all eight FIFO batches before rebuilding', () async {
    await service.reconcile([registration('a'), registration('b')]);
    final old = nodes.single;
    final updates = <_Update>[];
    for (var i = 0; i < 8; i++) {
      final a = _Update(500000 + i), b = _Update(500000 + i);
      updates.addAll([a, b]);
      old.batches.add({ids[0]: a, ids[1]: b});
    }
    old.overflow = true;
    await _until(() => nodes.length == 2);
    expect(published, [
      for (var i = 0; i < 8; i++) ...['a', 'b'],
    ]);
    expect(heights, [
      for (var i = 0; i < 8; i++) ...[500000 + i, 500000 + i],
    ]);
    expect(updates.every((update) => update.disposed), isTrue);
    expect(old.disposed, isTrue);
  });
  test(
    'renewal continues while FIFO application waits for its wallet lock',
    () async {
      await service.reconcile([registration('a')]);
      final entered = Completer<void>(), release = Completer<void>();
      final holder = coordinator.runExclusive(
        const WalletSourceKey('a', 'bitcoin', 'mainnet'),
        (_) async {
          entered.complete();
          await release.future;
        },
      );
      await entered.future;
      final old = nodes.single;
      final before = old.renewals;
      old.batches.add({ids.single: _Update(500000)});
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(old.renewals, greaterThan(before + 2));
      expect(published, isEmpty);
      release.complete();
      await holder;
      await _until(() => published.length == 1);
    },
  );

  test(
    'expired node with a delayed join rebuilds only after acknowledgement',
    () async {
      await service.reconcile([registration('a')]);
      final old = nodes.single..holdJoin = true;
      old.expired = true;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(nodes, hasLength(1));
      expect(old.disposed, isFalse);
      old.joined.complete();
      await _until(() => nodes.length == 2);
      expect(old.disposed, isTrue);
    },
  );

  test(
    'background overflow persists all eight prepared batches before returning',
    () async {
      final request = registration('a');
      await service.reconcile([request]);
      nodes.single.batches.add({ids.single: _Update(500000)});
      await _until(() => metadata.policies.length == 1);
      await service.stop();
      nodes.clear();
      published.clear();
      heights.clear();
      final catchUp = service.catchUp([
        request,
      ], DateTime.now().toUtc().add(const Duration(seconds: 5)));
      await _until(() => nodes.isNotEmpty);
      final old = nodes.single;
      final updates = <_Update>[];
      for (var i = 0; i < 8; i++) {
        final update = _Update(500001 + i);
        updates.add(update);
        old.batches.add({ids.single: update});
      }
      old.overflow = true;
      final results = await catchUp;
      expect(
        results[request.key],
        isA<Ok<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>(),
      );
      expect(heights, [for (var i = 0; i < 8; i++) 500001 + i]);
      expect(updates.every((update) => update.disposed), isTrue);
    },
  );

  test(
    'background apply admission expires without releasing a competing holder',
    () async {
      final request = registration('a');
      await service.reconcile([request]);
      nodes.single.batches.add({ids.single: _Update(500000)});
      await _until(() => metadata.policies.length == 1);
      await service.stop();
      nodes.clear();
      published.clear();
      final catchUp = service.catchUp([
        request,
      ], DateTime.now().toUtc().add(const Duration(seconds: 2)));
      await _until(() => nodes.isNotEmpty);
      final entered = Completer<void>(), release = Completer<void>();
      final holder = coordinator.runExclusive(
        const WalletSourceKey('a', 'bitcoin', 'mainnet'),
        (_) async {
          entered.complete();
          await release.future;
        },
      );
      await entered.future;
      nodes.single.batches.add({ids.single: _Update(500001)});
      try {
        await catchUp.timeout(const Duration(seconds: 3));
        await service.dispose().timeout(const Duration(seconds: 1));
        expect(published, isEmpty);
        expect(release.isCompleted, isFalse);
      } finally {
        release.complete();
        await holder;
      }
    },
  );
  test(
    'same-policy reconciliation drains overflow before replacing the stopped node',
    () async {
      final request = registration('a');
      await service.reconcile([request]);
      final old = nodes.single;
      for (var i = 0; i < 8; i++) {
        old.batches.add({ids.single: _Update(500000 + i)});
      }
      old.overflow = true;
      await service.reconcile([request]);
      expect(heights, [for (var i = 0; i < 8; i++) 500000 + i]);
      expect(nodes, hasLength(2));
      expect(loadedHeights.last, 500007);
    },
  );

  test(
    'overflow between an empty poll and status still drains its final batches',
    () async {
      await service.reconcile([registration('a')]);
      final old = nodes.single;
      old.onEmpty = () {
        for (var i = 0; i < 8; i++) {
          old.batches.add({ids.single: _Update(500000 + i)});
        }
        old.overflow = true;
      };
      await _until(() => nodes.length == 2);
      expect(heights, [for (var i = 0; i < 8; i++) 500000 + i]);
      expect(loadedHeights.last, 500007);
    },
  );
}
