import 'dart:io';
import 'dart:typed_data';

import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/write.dart';
import 'package:sync/sync.dart';
import 'package:sync/sync.dart' as sync show Wallet;
import 'package:sync/testing.dart' show MemoryFreezeStore;
import 'package:sqlite3/sqlite3.dart' show sqlite3;

final class _Catalog implements WalletCatalogPort {
  final Map<String, PublicWalletDescriptor> rows;
  bool failList = false;
  int listCalls = 0;

  _Catalog([Map<String, PublicWalletDescriptor>? rows]) : rows = rows ?? {};

  @override
  Future<Result<List<PublicWalletDescriptor>, SyncFailure>> list() async {
    listCalls++;
    if (failList) return const Err(SyncStorageFailure());
    return Ok(rows.values.toList());
  }

  @override
  Future<Result<PublicWalletDescriptor, SyncFailure>> find(
    WalletKey key,
  ) async {
    final descriptor = rows[key.id];
    if (descriptor == null || descriptor.key != key) {
      return const Err(SyncNotFoundFailure());
    }
    return Ok(descriptor);
  }
}

T _value<T>(Result<T, SyncFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw WalletSnapshotException(failure),
};

BitcoinWalletDescriptor _descriptor({
  required String id,
  required BitcoinNetwork network,
  required String external,
  required String internal,
}) => BitcoinWalletDescriptor(
  key: WalletKey(id: id, network: network),
  scriptType: ScriptType.bip84,
  origin: id,
  externalDescriptor: external,
  internalDescriptor: internal,
);

class _Reserved implements ReservedAddressPort {
  @override
  Future<Result<bool, SyncFailure>> isReserved(
    WalletKey key,
    String address,
  ) async => const Ok(false);
}

class _Offline implements WalletConnectionPort {
  @override
  Future<Result<T, SyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
  }) => throw StateError('Provisioning must be offline');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'failed service assembly closes metadata and permits a fresh open',
    () async {
      final directory = Directory.systemTemp.createTempSync('runtime-open-');
      final catalog = _Catalog();
      ForegroundStores? abandoned;
      var attempts = 0;
      final runtime = WalletNativeRuntime.open(
        catalog: catalog,
        reserved: _Reserved(),
        inputReservations: _NoInputReservations(),
        deleteCatalogEntry: (_) async => const Ok(null),
        sync: ElectrumSync(
          connections: _Offline(),
          documentsDirectory: () async => directory.path,
          readRevision: (_) async => const Err(SyncNotFoundFailure()),
        ),
        documentsDirectory: () async => directory.path,
        freezes: MemoryFreezeStore(),
        connections: _Offline(),
        onStoresOpened: (stores) {
          if (++attempts == 1) {
            abandoned = stores;
            throw const FileSystemException('assembly interrupted');
          }
        },
      );
      try {
        expect(await runtime.initialize(), isA<Err<void, SyncFailure>>());
        final failedStore = abandoned;
        expect(failedStore, isNotNull);
        if (failedStore == null) return;
        await expectLater(
          failedStore.revisions.read(
            WalletKey(id: 'probe', network: BitcoinNetwork.testnet),
          ),
          throwsStateError,
        );
        expect(await runtime.initialize(), isA<Ok<void, SyncFailure>>());
        expect(attempts, 2);
        expect(catalog.listCalls, 1);
      } finally {
        await runtime.close();
        directory.deleteSync(recursive: true);
      }
    },
  );
  test(
    'failed initialization can be retried without failing startup',
    () async {
      final directory = Directory.systemTemp.createTempSync('runtime-retry-');
      final catalog = _Catalog();
      var attempts = 0;
      final runtime = WalletNativeRuntime.open(
        catalog: catalog,
        reserved: _Reserved(),
        inputReservations: _NoInputReservations(),
        deleteCatalogEntry: (_) async => const Ok(null),
        sync: ElectrumSync(
          connections: _Offline(),
          documentsDirectory: () async => directory.path,
          readRevision: (_) async => const Err(SyncNotFoundFailure()),
        ),
        documentsDirectory: () async {
          if (++attempts == 1) throw const FileSystemException('unavailable');
          return directory.path;
        },
        freezes: MemoryFreezeStore(),
        connections: _Offline(),
      );
      try {
        expect(await runtime.initialize(), isA<Err<void, SyncFailure>>());
        expect(await runtime.initialize(), isA<Ok<void, SyncFailure>>());
        expect(attempts, 2);
      } finally {
        await runtime.close();
        directory.deleteSync(recursive: true);
      }
    },
  );
  test(
    'refresh tolerates an unknown key but reports revision storage failure',
    () async {
      final directory = Directory.systemTemp.createTempSync('runtime-refresh-');
      final catalog = _Catalog();
      final runtime = WalletNativeRuntime.open(
        catalog: catalog,
        reserved: _Reserved(),
        inputReservations: _NoInputReservations(),
        deleteCatalogEntry: (_) async => const Ok(null),
        sync: ElectrumSync(
          connections: _Offline(),
          documentsDirectory: () async => directory.path,
          readRevision: (_) async => const Err(SyncNotFoundFailure()),
        ),
        documentsDirectory: () async => directory.path,
        freezes: MemoryFreezeStore(),
        connections: _Offline(),
      );
      try {
        expect(await runtime.initialize(), isA<Ok<void, SyncFailure>>());
        final key = WalletKey(id: 'missing', network: BitcoinNetwork.testnet);
        expect(await runtime.refresh(key), isA<Ok<void, SyncFailure>>());
        final db = sqlite3.open(
          '${directory.path}/transaction_sync/revisions.sqlite',
        );
        try {
          db.execute('DROP TABLE revisions');
        } finally {
          db.close();
        }
        expect(
          await runtime.refresh(key),
          isA<Err<void, SyncFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<SyncStorageFailure>(),
          ),
        );
      } finally {
        await runtime.close();
        directory.deleteSync(recursive: true);
      }
    },
  );

  test('offline create, issued address, read and tombstone survive reopening', () async {
    final directory = Directory.systemTemp.createTempSync('native-runtime-');
    final mnemonic = bdk.Mnemonic.fromString(
      mnemonic: 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
    );
    final secret = bdk.DescriptorSecretKey(
      networkKind: bdk.NetworkKind.test,
      mnemonic: mnemonic,
      password: null,
    );
    String derive(bdk.KeychainKind chain) {
      final descriptor = bdk.Descriptor.newBip84(
        secretKey: secret,
        keychainKind: chain,
        networkKind: bdk.NetworkKind.test,
      );
      try {
        return descriptor.toString();
      } finally {
        descriptor.dispose();
      }
    }

    final row = _descriptor(
      id: 'wpkh([aabbccdd/84h/1h/0h])',
      network: BitcoinNetwork.testnet,
      external: derive(bdk.KeychainKind.external_),
      internal: derive(bdk.KeychainKind.internal),
    );
    secret.dispose();
    mnemonic.dispose();
    final rows = <String, PublicWalletDescriptor>{row.key.id: row};
    final deletedFromCatalog = <String>[];
    final catalog = _Catalog(rows);
    WalletNativeRuntime open() => WalletNativeRuntime.open(
      catalog: catalog,
      reserved: _Reserved(),
      inputReservations: _NoInputReservations(),
      deleteCatalogEntry: (key) async {
        deletedFromCatalog.add(key.id);
        rows.remove(key.id);
        return const Ok(null);
      },
      sync: ElectrumSync(
        connections: _Offline(),
        documentsDirectory: () async => directory.path,
        readRevision: (_) async => const Err(SyncNotFoundFailure()),
      ),
      documentsDirectory: () async => directory.path,
      freezes: MemoryFreezeStore(),
      connections: _Offline(),
    );
    var runtime = open();
    // A loaded handle proves the wallet available, as builders used to
    // prove it by borrowing the native one.
    Future<sync.Wallet> loaded(PublicWalletDescriptor model) async =>
        _value(await runtime.loadWallet(model.key));
    try {
      final unfinished = _descriptor(
        id: row.key.id,
        network: BitcoinNetwork.testnet,
        external: 'wpkh(invalid)',
        internal: row.internalDescriptor,
      );
      rows[row.key.id] = unfinished;
      expect(
        await runtime.create(
          WalletKey(id: unfinished.key.id, network: BitcoinNetwork.testnet),
        ),
        isA<Err<void, SyncFailure>>(),
      );
      expect(rows[row.key.id], unfinished);
      rows[row.key.id] = row;
      _value(await runtime.create(row.key));
      _value(await runtime.initialize());
      var address = _value(await runtime.receive(row.key));
      final wallet = await loaded(row);
      expect(wallet.balances.now.data?.totalSat, BigInt.zero);

      // A failed global enumeration does not hide a known wallet whose own
      // catalog entry and native stores remain available.
      catalog.failList = true;
      final degraded = open();
      try {
        final key = row.key;
        expect(await degraded.initialize(), isA<Err<void, SyncFailure>>());
        expect(await degraded.wallet(key), isA<Ok<sync.Wallet, SyncFailure>>());
        expect(
          await degraded.loadWallet(key),
          isA<Ok<sync.Wallet, SyncFailure>>(),
        );
        expect(_value(await degraded.receive(key)), address);
      } finally {
        await degraded.close();
        catalog.failList = false;
      }
      final revisions = <WalletRevisionState>[];
      final observation = runtime.changes.listen(revisions.add);
      final other = open();
      _value(await other.initialize());
      address = _value(await other.receive(row.key, advance: true));
      await other.close();
      await pumpEventQueue();
      expect(revisions, isEmpty);
      _value(await runtime.refreshAll());
      await pumpEventQueue();
      expect(revisions, hasLength(1));
      expect(revisions.single.lifecycle, WalletLifecycle.active);
      await observation.cancel();

      await runtime.close();
      runtime = open();
      _value(await runtime.initialize());
      expect(_value(await runtime.receive(row.key)), address);
      final advanced = _value(await runtime.receive(row.key, advance: true));
      expect(_value(await runtime.issuedReceiveIndex(row.key)), advanced.index);
      expect(advanced.index, address.index + 1);
      await runtime.close();
      final missing = _descriptor(
        id: 'wpkh([11223344/84h/1h/0h])',
        network: BitcoinNetwork.testnet,
        external: row.externalDescriptor,
        internal: row.internalDescriptor,
      );
      rows[missing.key.id] = missing;
      final missingKey = missing.key;
      final missingStore = File(
        nativeWalletStoragePath(directory.path, missingKey),
      );
      final metadataFile = File(
        '${directory.path}/transaction_sync/revisions.sqlite',
      );
      metadataFile.writeAsStringSync('corrupt revision metadata');
      runtime = open();
      // A global catalog failure leaves recovery pending across a restart.
      catalog.failList = true;
      expect(await runtime.initialize(), isA<Err<void, SyncFailure>>());
      final recoveryMarker = File('${metadataFile.path}.recovery');
      expect(recoveryMarker.existsSync(), isTrue);
      await runtime.close();
      catalog.failList = false;
      runtime = open();
      _value(await runtime.initialize());
      expect(missingStore.existsSync(), isFalse);
      final healthyKey = row.key;
      final beforeReads = await runtime.readRevision(healthyKey) as Ok;
      final listCallsBeforeReads = catalog.listCalls;
      for (var i = 0; i < 5; i++) {
        await loaded(row);
        await expectLater(
          loaded(missing),
          throwsA(isA<WalletSnapshotException>()),
        );
      }
      expect(catalog.listCalls, listCallsBeforeReads);
      final afterReads = await runtime.readRevision(healthyKey) as Ok;
      expect(
        (afterReads.value as WalletRevisionState).stamp,
        (beforeReads.value as WalletRevisionState).stamp,
      );
      expect(recoveryMarker.existsSync(), isFalse);
      _value(await runtime.resumeProvisioning());
      expect(
        missingStore.existsSync(),
        isTrue,
        reason: 'a completed adoption pass permits explicit provisioning',
      );
      await runtime.close();
      runtime = open();
      _value(await runtime.initialize());
      expect(await loaded(missing), isA<sync.Wallet>());
      rows.remove(missing.key.id);
      final adopted = await loaded(row);
      expect(adopted.balances.now.data?.totalSat, BigInt.zero);
      expect(
        metadataFile.parent.listSync().where(
          (file) => file.path.contains('.corrupt-'),
        ),
        isNotEmpty,
      );
      _value(await runtime.delete(row.key));
      await expectLater(loaded(row), throwsA(isA<WalletSnapshotException>()));
      // Simulate crash after writer.delete and before catalog deletion.
      expect(rows, isNotEmpty);
      await runtime.close();
      runtime = open();
      _value(await runtime.initialize());
      expect(rows, isEmpty);
      expect(deletedFromCatalog, [row.key.id]);
      // Re-import is interrupted after its catalog row becomes visible.
      _value(await runtime.prepareCreate(row.key));
      rows[row.key.id] = row;
      await runtime.close();
      runtime = open();
      _value(await runtime.initialize());
      expect(rows[row.key.id], row);
      expect(await loaded(row), isA<sync.Wallet>());
      // If corruption destroys a deletion tombstone before catalog removal,
      // the surviving row is indistinguishable from an interrupted import.
      _value(await runtime.delete(row.key));
      await runtime.close();
      metadataFile.writeAsStringSync('corrupt deletion metadata');
      runtime = open();
      _value(await runtime.initialize());
      await expectLater(loaded(row), throwsA(isA<WalletSnapshotException>()));
      expect(recoveryMarker.existsSync(), isFalse);
      _value(await runtime.resumeProvisioning());
      expect(
        await loaded(row),
        isA<sync.Wallet>(),
        reason:
            'documented residual: lost deletion metadata permits reappearance',
      );
    } finally {
      await runtime.close();
      directory.deleteSync(recursive: true);
    }
  });

  test('a broadcast expected on another network is refused, unsent', () async {
    final directory = Directory.systemTemp.createTempSync('runtime-net-');
    final mnemonic = bdk.Mnemonic.fromString(
      mnemonic: 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
    );
    final secret = bdk.DescriptorSecretKey(
      networkKind: bdk.NetworkKind.main,
      mnemonic: mnemonic,
      password: null,
    );
    String derive(bdk.KeychainKind chain) {
      final descriptor = bdk.Descriptor.newBip84(
        secretKey: secret,
        keychainKind: chain,
        networkKind: bdk.NetworkKind.main,
      );
      try {
        return descriptor.toString();
      } finally {
        descriptor.dispose();
      }
    }

    final row = _descriptor(
      id: 'wpkh([aabbccdd/84h/0h/0h])',
      network: BitcoinNetwork.mainnet,
      external: derive(bdk.KeychainKind.external_),
      internal: derive(bdk.KeychainKind.internal),
    );
    secret.dispose();
    mnemonic.dispose();
    final catalog = _Catalog({row.key.id: row});
    // Any server contact throws: the refusal must come before transport.
    final runtime = WalletNativeRuntime.open(
      catalog: catalog,
      reserved: _Reserved(),
      inputReservations: _NoInputReservations(),
      deleteCatalogEntry: (_) async => const Ok(null),
      sync: ElectrumSync(
        connections: _Offline(),
        documentsDirectory: () async => directory.path,
        readRevision: (_) async => const Err(SyncNotFoundFailure()),
      ),
      documentsDirectory: () async => directory.path,
      freezes: MemoryFreezeStore(),
      connections: _Offline(),
    );
    try {
      _value(await runtime.create(row.key));
      final result = await runtime.broadcast(
        row.key,
        SignedBitcoinTransaction(_transaction()),
        network: BitcoinNetwork.testnet,
      );
      expect(
        result,
        isA<Err<SpendReceipt, SyncFailure>>().having(
          (err) => err.failure,
          'failure',
          isA<SyncSpendBlockedFailure>().having(
            (blocked) => blocked.status,
            'status',
            BitcoinSpendStatus.unavailable,
          ),
        ),
      );
    } finally {
      await runtime.close();
      directory.deleteSync(recursive: true);
    }
  });
}

/// A one-input, one-output transaction in its consensus serialization.
Uint8List _transaction() => Uint8List.fromList([
  2, 0, 0, 0, 1, //
  ...List.filled(32, 0xaa), 0, 0, 0, 0, 0, 0xfd, 0xff, 0xff, 0xff, //
  1, 0x10, 0x27, 0, 0, 0, 0, 0, 0, 22, 0, 20, ...List.filled(20, 7), //
  0, 0, 0, 0,
]);

final class _NoInputReservations implements InputReservationPort {
  @override
  Future<Result<List<InputReservation>, SyncFailure>> reservations() async =>
      const Ok([]);
}
