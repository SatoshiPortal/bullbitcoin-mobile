import 'package:sync/src/data/datasources/spend_gate_store_datasource.dart';
import 'package:sync/src/data/read/persisted_wallet_readiness.dart';
import 'package:sync/src/data/native_store_paths.dart';
import 'package:sync/src/data/read/native_frame_source.dart';
import 'package:sync/src/data/wallet_projections.dart';
import 'package:sync/src/data/write/native_wallet_writer_repository.dart';
import 'package:sync/src/data/datasources/revision_store_datasource.dart';
import 'package:sync/src/data/sqlite_wallet_revision_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:sync/diagnostics.dart';

import 'dart:io';

import 'package:bull_logger/bull_logger.dart';

import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/src/data/read/wallet_snapshot_reader.dart';
import 'package:sync/sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Directory documents;
  late WalletSnapshotReader reader;
  late BitcoinWalletDescriptor descriptor;
  late FakeRevisions revisions;
  late FakeReadiness readiness;
  late FakeAdmission admission;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('snapshot-test-');
    log = Logger.replace(directory: directory);
    documents = await Directory('${directory.path}/documents').create();
    final key = WalletKey(id: 'reader-test', network: BitcoinNetwork.testnet);
    revisions = FakeRevisions(key);
    readiness = FakeReadiness();
    admission = FakeAdmission(revisions);
    reader = WalletSnapshotReader(
      documentsDirectory: documents.path,
      readiness: readiness,
      requiredSchemaVersion: 1,
      revisions: revisions,
      liquidAdmission: admission,
    );
    // Published BIP39 test vector; no application key material.
    final mnemonic = bdk.Mnemonic.fromString(
      mnemonic:
          'abandon abandon abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon about',
    );
    final secret = bdk.DescriptorSecretKey(
      networkKind: bdk.NetworkKind.test,
      mnemonic: mnemonic,
      password: null,
    );
    final external = bdk.Descriptor.newBip84(
      secretKey: secret,
      keychainKind: bdk.KeychainKind.external_,
      networkKind: bdk.NetworkKind.test,
    );
    final internal = bdk.Descriptor.newBip84(
      secretKey: secret,
      keychainKind: bdk.KeychainKind.internal,
      networkKind: bdk.NetworkKind.test,
    );
    descriptor = BitcoinWalletDescriptor(
      key: key,
      scriptType: ScriptType.bip84,
      origin: 'test',
      externalDescriptor: external.toString(),
      internalDescriptor: internal.toString(),
    );
    readiness.initializedDescriptor = descriptor;
    external.dispose();
    internal.dispose();
    secret.dispose();
    mnemonic.dispose();
  });
  tearDown(() async {
    await log.flush();
    await directory.delete(recursive: true);
  });

  test('reader failure category persists once across repeated reads', () async {
    readiness.initializedDescriptor = null;
    for (var i = 0; i < 3; i++) {
      await reader.bitcoin(descriptor);
    }
    final rows = await log.readLogs();
    expect(
      rows.where((row) => row.contains('Wallet reader state:')),
      hasLength(1),
    );
    expect(rows.join(), isNot(contains('[REDACTED]')));
    expect(rows.join(), isNot(contains('Failure')));
  });

  void create({int revealed = 0}) {
    final persister = bdk.Persister.newSqlite(
      path: nativeWalletStoragePath(documents.path, descriptor.key),
    );
    final external = bdk.Descriptor(
      descriptor: descriptor.externalDescriptor,
      networkKind: bdk.NetworkKind.test,
    );
    final internal = bdk.Descriptor(
      descriptor: descriptor.internalDescriptor,
      networkKind: bdk.NetworkKind.test,
    );
    final wallet = bdk.Wallet(
      descriptor: external,
      changeDescriptor: internal,
      network: bdk.Network.testnet,
      persister: persister,
      lookahead: 25,
    );
    for (final address in wallet.revealAddressesTo(
      keychain: bdk.KeychainKind.external_,
      index: revealed,
    )) {
      address.address.dispose();
    }
    wallet.persist(persister: persister);
    wallet.dispose();
    persister.dispose();
    external.dispose();
    internal.dispose();
  }

  test('native reader logs hydrate and cache leases with caller context', () async {
    create();
    final store = RevisionStoreDatasource.openForeground(
      revisionStorePath(documents.path),
    );
    SpendGateStoreDatasource.provision(spendGateStorePath(documents.path));
    final writer = NativeWalletWriterRepository(
      revisions: store,
      reader: SqliteWalletRevisionReader(store),
      documentsDirectory: documents.path,
      catalog: _Catalog(descriptor),
      reservedAddresses: _Reserved(),
    );
    final console = <String>[];
    final previous = debugPrint;
    try {
      expect(
        await writer.create(
          descriptor.key,
          expectedGeneration: 0,
          existingOnly: true,
        ),
        isA<Ok>(),
      );
      reader = WalletSnapshotReader(
        documentsDirectory: documents.path,
        readiness: PersistedWalletReadiness(store),
        requiredSchemaVersion: writerSchemaVersion,
        revisions: SqliteWalletRevisionReader(store),
        liquidAdmission: writer,
      );
      debugPrint = (message, {wrapWidth}) {
        if (message != null) console.add(message);
      };
      for (var i = 0; i < 2; i++) {
        expect(
          await LeaseDiagnostics.from(
            LeaseSource.syncStarted,
            () => reader.bitcoin(descriptor),
          ),
          isA<Ok>(),
        );
      }
      await log.flush();
      await pumpEventQueue();
      final rows = console
          .where((line) => line.contains('event=lease_'))
          .toList();
      expect(
        rows.where((line) => line.contains('event=lease_acquire')),
        hasLength(2),
      );
      final releases = rows
          .where((line) => line.contains('event=lease_release'))
          .toList();
      expect(releases, hasLength(2));
      expect(releases.first, contains('read=hydrate'));
      expect(releases.last, contains('read=cache'));
      expect(
        rows.every(
          (line) => line.contains(
            'role=reader intent=snapshot scope=foreground source=sync_started',
          ),
        ),
        isTrue,
      );
    } finally {
      debugPrint = previous;
      store.close();
    }
  });

  test('writer adopts the previously revealed receive index', () async {
    create(revealed: 12);
    final revisions = RevisionStoreDatasource.openForeground(
      revisionStorePath(documents.path),
    );
    SpendGateStoreDatasource.provision(spendGateStorePath(documents.path));
    final writer = NativeWalletWriterRepository(
      revisions: revisions,
      reader: SqliteWalletRevisionReader(revisions),
      documentsDirectory: documents.path,
      catalog: _Catalog(descriptor),
      reservedAddresses: _Reserved(),
    );
    try {
      expect(
        await writer.create(
          descriptor.key,
          expectedGeneration: 0,
          existingOnly: true,
        ),
        isA<Ok>(),
      );
      final first = await writer.receive(
        descriptor.key,
        expectedGeneration: 0,
      ) as Ok<ReceiveAddressIssued, SyncFailure>;
      expect(first.value.index, 12);
      final reopened = NativeWalletWriterRepository(
        revisions: revisions,
        reader: SqliteWalletRevisionReader(revisions),
        documentsDirectory: documents.path,
        catalog: _Catalog(descriptor),
        reservedAddresses: _Reserved(),
      );
      final again = await reopened.receive(
        descriptor.key,
        expectedGeneration: 0,
      ) as Ok<ReceiveAddressIssued, SyncFailure>;
      expect(again.value.address, first.value.address);
      expect(again.value.index, 12);
      final next = await reopened.receive(
        descriptor.key,
        expectedGeneration: 0,
        advance: true,
      ) as Ok<ReceiveAddressIssued, SyncFailure>;
      expect(next.value.index, 13);
      final same = await reopened.receive(
        descriptor.key,
        expectedGeneration: 0,
      ) as Ok<ReceiveAddressIssued, SyncFailure>;
      expect(same.value.address, next.value.address);
    } finally {
      revisions.close();
    }
  });

  test(
    'read and cached read preserve real bytes and directory listing',
    () async {
      create();
      final before = await fingerprint(documents);
      final first = await reader.bitcoin(descriptor);
      expect(first, isA<Ok<WalletReadSnapshot<bdk.Wallet>, SyncFailure>>());
      final wallet = (first as Ok<WalletReadSnapshot<bdk.Wallet>, SyncFailure>)
          .value
          .wallet;
      // The loaded handle exposes the persisted derivation state.
      expect(
        wallet.nextDerivationIndex(keychain: bdk.KeychainKind.external_),
        1,
      );
      final second = await reader.bitcoin(descriptor);
      expect(
        (second as Ok<WalletReadSnapshot<bdk.Wallet>, SyncFailure>)
            .value
            .wallet,
        same(wallet),
      );
      expect(await fingerprint(documents), before);
      revisions.state = WalletRevisionState(
        stamp: revisions.state.stamp,
        lifecycle: WalletLifecycle.pendingWrite,
      );
      final stale = await reader.bitcoin(descriptor);
      expect(
        (stale as Ok<WalletReadSnapshot<bdk.Wallet>, SyncFailure>).value.stale,
        isTrue,
      );
      // Hydrated, then served from cache under the lease: both admitted. The
      // cache served while the writer holds the wallet is not.
      expect(
        [first.value.admitted, second.value.admitted, stale.value.admitted],
        [isTrue, isTrue, isFalse],
      );
      revisions.state = WalletRevisionState(
        stamp: WalletRevision(key: descriptor.key, generation: 1, revision: 0),
        lifecycle: WalletLifecycle.pendingWrite,
      );
      expect(
        await reader.bitcoin(descriptor),
        isA<Err<WalletReadSnapshot<bdk.Wallet>, SyncFailure>>(),
      );
    },
  );

  test(
    'BDK hydration holds admission and releases before snapshot reads',
    () async {
      create();
      readiness.onCheck = () => expect(admission.active, isTrue);
      expect(await reader.bitcoin(descriptor), isA<Ok>());
      expect(admission.active, isFalse);
    },
  );

  test(
    'BDK busy admission serves a stale cached snapshot without opening',
    () async {
      create();
      expect(await reader.bitcoin(descriptor), isA<Ok>());
      admission.busy = true;
      final result = await reader.bitcoin(descriptor) as Ok;
      expect((result.value as WalletReadSnapshot).stale, isTrue);
      expect((result.value as WalletReadSnapshot).admitted, isFalse);
    },
  );

  test(
    'maps asynchronous stale revision read failures to storage failure',
    () async {
      create();
      expect(await reader.bitcoin(descriptor), isA<Ok>());
      admission.busy = true;
      var reads = 0;
      revisions.beforeRead = () {
        if (++reads == 2) {
          throw const FileSystemException('revision unavailable');
        }
      };

      final result = await reader.bitcoin(descriptor);

      expect((result as Err).failure, isA<SyncStorageFailure>());
      expect(reads, 2);
    },
  );

  test('missing store is typed and creates nothing', () async {
    final result = await reader.bitcoin(descriptor);
    expect((result as Err).failure, isA<SyncNotFoundFailure>());
    expect(await documents.list().toList(), isEmpty);
  });

  test(
    'corrupt store is a storage failure, neither repaired nor deleted',
    () async {
      await File(nativeWalletStoragePath(documents.path, descriptor.key))
          .writeAsString('not a wallet');
      final before = await fingerprint(documents);
      final result = await reader.bitcoin(descriptor);
      // Repair only answers LWK's status conflict: it cannot fix this store.
      expect((result as Err).failure, isA<SyncStorageFailure>());
      expect(await fingerprint(documents), before);
    },
  );

  test('uninitialized and old-schema stores are never opened', () async {
    create();
    for (final version in [null, 0]) {
      readiness.schemaVersion = version;
      final before = await fingerprint(documents);
      expect(
        (await reader.bitcoin(descriptor) as Err).failure,
        isA<SyncBusyFailure>(),
      );
      expect(await fingerprint(documents), before);
    }
  });

  test(
    'hydration revision race retains the previous snapshot as stale',
    () async {
      create();
      final first = await reader.bitcoin(
        descriptor,
      ) as Ok<WalletReadSnapshot<bdk.Wallet>, SyncFailure>;
      revisions.state = WalletRevisionState(
        stamp: WalletRevision(key: descriptor.key, generation: 0, revision: 1),
        lifecycle: WalletLifecycle.active,
        initializedSchema: 1,
      );
      var reads = 0;
      revisions.beforeRead = () {
        if (++reads == 2) {
          revisions.state = WalletRevisionState(
            stamp: WalletRevision(
              key: descriptor.key,
              generation: 0,
              revision: 2,
            ),
            lifecycle: WalletLifecycle.pendingWrite,
            initializedSchema: 1,
          );
        }
      };
      final raced = await reader.bitcoin(descriptor);
      expect(raced, isA<Ok>());
      if (raced case Ok(:final value)) {
        expect(value.stale, isTrue);
        expect(value.admitted, isFalse);
        expect(value.wallet, same(first.value.wallet));
        expect(value.revision, first.value.revision);
      }
      final retry = await reader.bitcoin(descriptor);
      expect(retry, isA<Ok>());
    },
  );

  test('failed sync leaves the same revision readable as stale', () async {
    create();
    final first = await reader.bitcoin(
      descriptor,
    ) as Ok<WalletReadSnapshot<bdk.Wallet>, SyncFailure>;
    revisions.state = WalletRevisionState(
      stamp: revisions.state.stamp,
      lifecycle: WalletLifecycle.active,
      initializedSchema: 1,
      syncFailed: true,
    );
    final next = await reader.bitcoin(
      descriptor,
    ) as Ok<WalletReadSnapshot<bdk.Wallet>, SyncFailure>;
    expect(next.value.wallet, same(first.value.wallet));
    expect(next.value.stale, isTrue);
    // A failed sync is stale, yet still the committed revision.
    expect(next.value.admitted, isTrue);
  });

  test(
    'red-green: a revision is mapped once, whatever its staleness',
    () async {
      create();
      final source = NativeFrameSource(reader, _Catalog(descriptor));
      WalletFrame frame(Result<LoadedFrame, SyncFailure> result) =>
          (result as Ok<LoadedFrame, SyncFailure>).value.frame;
      final fresh = frame(await source.load(descriptor.key, null));
      expect(fresh.stale, isFalse);
      // A writer holds the wallet: the reader serves its cache, stale.
      revisions.state = WalletRevisionState(
        stamp: revisions.state.stamp,
        lifecycle: WalletLifecycle.pendingWrite,
        initializedSchema: 1,
      );
      final busy = frame(await source.load(descriptor.key, fresh));
      revisions.state = WalletRevisionState(
        stamp: revisions.state.stamp,
        lifecycle: WalletLifecycle.active,
        initializedSchema: 1,
      );
      final back = frame(await source.load(descriptor.key, busy));
      expect([busy.stale, back.stale], [isTrue, isFalse]);
      for (final next in [busy, back]) {
        expect(next.revision, fresh.revision);
        // Only the status changed: the mapped values are the same objects.
        expect(next.balances, same(fresh.balances));
        expect(next.coins, same(fresh.coins));
        expect(next.transactions, same(fresh.transactions));
        expect(next.addresses, same(fresh.addresses));
        expect(next.ownership, same(fresh.ownership));
      }
    },
  );

  test('lease releases even when unpublished native disposal throws', () async {
    create();
    reader = WalletSnapshotReader(
      documentsDirectory: documents.path,
      readiness: readiness,
      requiredSchemaVersion: 1,
      revisions: revisions,
      liquidAdmission: admission,
      disposeUnpublished: (wallet) {
        (wallet as bdk.Wallet).dispose();
        throw StateError('dispose failure');
      },
    );
    var reads = 0;
    revisions.beforeRead = () {
      if (++reads == 2) {
        revisions.state = WalletRevisionState(
          stamp: WalletRevision(
            key: descriptor.key,
            generation: 1,
            revision: 0,
          ),
          lifecycle: WalletLifecycle.active,
          initializedSchema: 1,
        );
      }
    };
    await expectLater(reader.bitcoin(descriptor), throwsStateError);
    expect(admission.active, isFalse);
  });

  test('revision changed during hydration is never cached', () async {
    create();
    var reads = 0;
    revisions.beforeRead = () {
      if (++reads == 2) {
        revisions.state = WalletRevisionState(
          stamp: WalletRevision(
            key: descriptor.key,
            generation: 1,
            revision: 0,
          ),
          lifecycle: WalletLifecycle.active,
          initializedSchema: 1,
        );
      }
    };
    expect(
      (await reader.bitcoin(descriptor) as Err).failure,
      isA<SyncBusyFailure>(),
    );
    expect(await reader.bitcoin(descriptor), isA<Ok>());
  });
}

Future<Map<String, String>> fingerprint(Directory directory) async {
  final result = <String, String>{};
  await for (final entry in directory.list(
    recursive: true,
    followLinks: false,
  )) {
    result[entry.path.substring(directory.path.length)] = entry is File
        ? sha256.convert(await entry.readAsBytes()).toString()
        : entry is Directory
        ? 'directory'
        : 'link';
  }
  return result;
}

final class FakeRevisions implements WalletRevisionReaderPort {
  WalletRevisionState state;
  void Function()? beforeRead;
  FakeRevisions(WalletKey key)
    : state = WalletRevisionState(
        stamp: WalletRevision(key: key, generation: 0, revision: 0),
        lifecycle: WalletLifecycle.active,
        initializedSchema: 1,
      );
  @override
  Future<Result<WalletRevisionState, SyncFailure>> read(WalletKey key) async {
    beforeRead?.call();
    return Ok(state);
  }

  @override
  Stream<WalletRevisionState> watch(WalletKey key) => const Stream.empty();
}

final class FakeAdmission implements ReadAdmissionPort {
  final FakeRevisions revisions;
  bool busy = false;
  bool active = false;
  FakeAdmission(this.revisions);
  @override
  Future<Result<ReadLease, SyncFailure>> acquire(WalletKey key) async {
    if (busy) return const Err(SyncBusyFailure());
    active = true;
    return Ok(_FakeLease(revisions.state.stamp, () => active = false));
  }
}

final class _FakeLease implements ReadLease {
  @override
  final WalletRevision revision;
  final void Function() onRelease;
  _FakeLease(this.revision, this.onRelease);
  @override
  Future<void> release() async => onRelease();
}

final class FakeReadiness implements WalletReadReadinessPort {
  int? schemaVersion = 1;
  String? liquidCachePath;
  PublicWalletDescriptor? initializedDescriptor;
  void Function()? onCheck;

  @override
  Future<Result<WalletReadReady, SyncFailure>> check(
    PublicWalletDescriptor descriptor,
    WalletRevision expected,
    int requiredSchemaVersion,
  ) async {
    onCheck?.call();
    if (!identical(descriptor, initializedDescriptor)) {
      return const Err(SyncInvalidCatalogFailure());
    }
    final version = schemaVersion;
    if (version == null) {
      return const Err(SyncBusyFailure());
    }
    return Ok(
      WalletReadReady(
        revision: expected,
        schemaVersion: version,
        liquidCachePath: liquidCachePath,
      ),
    );
  }
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

final class _Reserved implements ReservedAddressPort {
  @override
  Future<Result<bool, SyncFailure>> isReserved(
    WalletKey key,
    String address,
  ) async => const Ok(false);
}
