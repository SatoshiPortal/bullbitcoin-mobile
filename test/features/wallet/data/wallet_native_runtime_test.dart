import '../../../support/wallet_registrations.dart';

import 'dart:io';
import 'dart:typed_data';

import 'package:legacy_storage/app_database.dart' show Signer;
import 'package:bb_mobile/features/wallet/data/wallet_registrations.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/wallet_sync_binding.dart';
import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/write.dart';
import 'package:sync/sync.dart';
import 'package:sync/sync.dart' as sync show Wallet;
import 'package:sync/testing.dart' show MemoryFreezeStore;
import 'package:sqlite3/sqlite3.dart' show sqlite3;

class _Metadata extends Mock implements WalletRegistrations {}

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
      final metadata = _Metadata();
      when(() => metadata.fetchAll()).thenAnswer((_) async => []);
      ForegroundStores? abandoned;
      var attempts = 0;
      final runtime = WalletNativeRuntime.open(
        catalog: TestWalletCatalog(metadata),
        reserved: _Reserved(),
        inputReservations: _NoInputReservations(),
        deleteCatalogEntry: (key) async {
          await metadata.delete(key.id);
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
        verify(() => metadata.fetchAll()).called(1);
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
      final metadata = _Metadata();
      when(() => metadata.fetchAll()).thenAnswer((_) async => []);
      var attempts = 0;
      final runtime = WalletNativeRuntime.open(
        catalog: TestWalletCatalog(metadata),
        reserved: _Reserved(),
        inputReservations: _NoInputReservations(),
        deleteCatalogEntry: (key) async {
          await metadata.delete(key.id);
          return const Ok(null);
        },
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
      final metadata = _Metadata();
      when(() => metadata.fetchAll()).thenAnswer((_) async => []);
      final runtime = WalletNativeRuntime.open(
        catalog: TestWalletCatalog(metadata),
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

    final row = WalletMetadataModel(
      networkCode: 'bitcoinTestnet',
      id: 'wpkh([aabbccdd/84h/1h/0h])',
      masterFingerprint: 'aabbccdd',
      xpubFingerprint: 'aabbccdd',
      isEncryptedVaultTested: false,
      isPhysicalBackupTested: false,
      xpub: 'public',
      externalPublicDescriptor: derive(bdk.KeychainKind.external_),
      internalPublicDescriptor: derive(bdk.KeychainKind.internal),
      signer: Signer.none,
      isDefault: false,
    );
    secret.dispose();
    mnemonic.dispose();
    final rows = <String, WalletMetadataModel>{row.id: row};
    final metadata = _Metadata();
    when(() => metadata.fetchAll())
        .thenAnswer((_) async => rows.values.toList());
    when(() => metadata.fetch(row.id)).thenAnswer((_) async => rows[row.id]);
    when(() => metadata.delete(row.id)).thenAnswer((_) async {
      rows.remove(row.id);
    });
    WalletNativeRuntime open() => WalletNativeRuntime.open(
      catalog: TestWalletCatalog(metadata),
      reserved: _Reserved(),
      inputReservations: _NoInputReservations(),
      deleteCatalogEntry: (key) async {
        await metadata.delete(key.id);
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
    Future<sync.Wallet> loaded(WalletMetadataModel model) async =>
        WalletSyncBinding.value(
          await runtime.loadWallet(
            (WalletSyncBinding.descriptorFromMetadata(
              model,
            ) as Ok<PublicWalletDescriptor, SyncFailure>).value.key,
          ),
        );
    try {
      final unfinished = row.copyWith(
        externalPublicDescriptor: 'wpkh(invalid)',
      );
      rows[row.id] = unfinished;
      expect(
        await runtime.create(
          WalletKey(id: unfinished.id, network: BitcoinNetwork.testnet),
        ),
        isA<Err<void, SyncFailure>>(),
      );
      expect(rows[row.id], unfinished);
      rows[row.id] = row;
      WalletSyncBinding.value(
        await runtime.create(WalletSyncBinding.keyFromMetadata(row)),
      );
      WalletSyncBinding.value(await runtime.initialize());
      var address = WalletSyncBinding.value(
        await runtime.receive(WalletSyncBinding.keyFromMetadata(row)),
      );
      final wallet = await loaded(row);
      expect(wallet.balances.now.data?.totalSat, BigInt.zero);

      // A failed global enumeration does not hide a known wallet whose own
      // catalog entry and native stores remain available.
      when(() => metadata.fetchAll())
          .thenThrow(const FileSystemException('catalog unavailable'));
      final degraded = open();
      try {
        final key = WalletSyncBinding.keyFromMetadata(row);
        expect(await degraded.initialize(), isA<Err<void, SyncFailure>>());
        expect(await degraded.wallet(key), isA<Ok<sync.Wallet, SyncFailure>>());
        expect(
          await degraded.loadWallet(key),
          isA<Ok<sync.Wallet, SyncFailure>>(),
        );
        expect(WalletSyncBinding.value(await degraded.receive(key)), address);
      } finally {
        await degraded.close();
        when(() => metadata.fetchAll())
            .thenAnswer((_) async => rows.values.toList());
      }
      final revisions = <WalletRevisionState>[];
      final observation = runtime.changes.listen(revisions.add);
      final other = open();
      WalletSyncBinding.value(await other.initialize());
      address = WalletSyncBinding.value(
        await other.receive(
          WalletSyncBinding.keyFromMetadata(row),
          advance: true,
        ),
      );
      await other.close();
      await pumpEventQueue();
      expect(revisions, isEmpty);
      WalletSyncBinding.value(await runtime.refreshAll());
      await pumpEventQueue();
      expect(revisions, hasLength(1));
      expect(revisions.single.lifecycle, WalletLifecycle.active);
      await observation.cancel();

      await runtime.close();
      runtime = open();
      WalletSyncBinding.value(await runtime.initialize());
      expect(
        WalletSyncBinding.value(
          await runtime.receive(WalletSyncBinding.keyFromMetadata(row)),
        ),
        address,
      );
      final advanced = WalletSyncBinding.value(
        await runtime.receive(
          WalletSyncBinding.keyFromMetadata(row),
          advance: true,
        ),
      );
      expect(
        WalletSyncBinding.value(
          await runtime.issuedReceiveIndex(
            WalletSyncBinding.keyFromMetadata(row),
          ),
        ),
        advanced.index,
      );
      expect(advanced.index, address.index + 1);
      await runtime.close();
      final missing = row.copyWith(id: 'wpkh([11223344/84h/1h/0h])');
      rows[missing.id] = missing;
      when(() => metadata.fetch(missing.id))
          .thenAnswer((_) async => rows[missing.id]);
      final missingKey = (WalletSyncBinding.descriptorFromMetadata(
        missing,
      ) as Ok<PublicWalletDescriptor, SyncFailure>).value.key;
      final missingStore = File(
        nativeWalletStoragePath(directory.path, missingKey),
      );
      final metadataFile = File(
        '${directory.path}/transaction_sync/revisions.sqlite',
      );
      metadataFile.writeAsStringSync('corrupt revision metadata');
      runtime = open();
      // A global catalog failure leaves recovery pending across a restart.
      when(() => metadata.fetchAll())
          .thenThrow(const FileSystemException('catalog unavailable'));
      expect(await runtime.initialize(), isA<Err<void, SyncFailure>>());
      final recoveryMarker = File('${metadataFile.path}.recovery');
      expect(recoveryMarker.existsSync(), isTrue);
      await runtime.close();
      when(() => metadata.fetchAll())
          .thenAnswer((_) async => rows.values.toList());
      runtime = open();
      WalletSyncBinding.value(await runtime.initialize());
      expect(missingStore.existsSync(), isFalse);
      final healthyKey = (WalletSyncBinding.descriptorFromMetadata(
        row,
      ) as Ok<PublicWalletDescriptor, SyncFailure>).value.key;
      final beforeReads = await runtime.readRevision(healthyKey) as Ok;
      clearInteractions(metadata);
      for (var i = 0; i < 5; i++) {
        await loaded(row);
        await expectLater(
          loaded(missing),
          throwsA(isA<WalletSnapshotException>()),
        );
      }
      verifyNever(() => metadata.fetchAll());
      final afterReads = await runtime.readRevision(healthyKey) as Ok;
      expect(
        (afterReads.value as WalletRevisionState).stamp,
        (beforeReads.value as WalletRevisionState).stamp,
      );
      expect(recoveryMarker.existsSync(), isFalse);
      WalletSyncBinding.value(await runtime.resumeProvisioning());
      expect(
        missingStore.existsSync(),
        isTrue,
        reason: 'a completed adoption pass permits explicit provisioning',
      );
      await runtime.close();
      runtime = open();
      WalletSyncBinding.value(await runtime.initialize());
      expect(await loaded(missing), isA<sync.Wallet>());
      rows.remove(missing.id);
      final adopted = await loaded(row);
      expect(adopted.balances.now.data?.totalSat, BigInt.zero);
      expect(
        metadataFile.parent.listSync().where(
          (file) => file.path.contains('.corrupt-'),
        ),
        isNotEmpty,
      );
      WalletSyncBinding.value(
        await runtime.delete(WalletSyncBinding.keyFromMetadata(row)),
      );
      await expectLater(loaded(row), throwsA(isA<WalletSnapshotException>()));
      // Simulate crash after writer.delete and before catalog deletion.
      expect(rows, isNotEmpty);
      await runtime.close();
      runtime = open();
      WalletSyncBinding.value(await runtime.initialize());
      expect(rows, isEmpty);
      verify(() => metadata.delete(row.id)).called(1);
      // Re-import is interrupted after its catalog row becomes visible.
      WalletSyncBinding.value(
        await runtime.prepareCreate(WalletSyncBinding.keyFromMetadata(row)),
      );
      rows[row.id] = row;
      await runtime.close();
      runtime = open();
      WalletSyncBinding.value(await runtime.initialize());
      expect(rows[row.id], row);
      expect(await loaded(row), isA<sync.Wallet>());
      // If corruption destroys a deletion tombstone before catalog removal,
      // the surviving row is indistinguishable from an interrupted import.
      WalletSyncBinding.value(
        await runtime.delete(WalletSyncBinding.keyFromMetadata(row)),
      );
      await runtime.close();
      metadataFile.writeAsStringSync('corrupt deletion metadata');
      runtime = open();
      WalletSyncBinding.value(await runtime.initialize());
      await expectLater(loaded(row), throwsA(isA<WalletSnapshotException>()));
      expect(recoveryMarker.existsSync(), isFalse);
      WalletSyncBinding.value(await runtime.resumeProvisioning());
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

    final row = WalletMetadataModel(
      networkCode: 'bitcoinMainnet',
      id: 'wpkh([aabbccdd/84h/0h/0h])',
      masterFingerprint: 'aabbccdd',
      xpubFingerprint: 'aabbccdd',
      isEncryptedVaultTested: false,
      isPhysicalBackupTested: false,
      xpub: 'public',
      externalPublicDescriptor: derive(bdk.KeychainKind.external_),
      internalPublicDescriptor: derive(bdk.KeychainKind.internal),
      signer: Signer.none,
      isDefault: false,
    );
    secret.dispose();
    mnemonic.dispose();
    final metadata = _Metadata();
    when(() => metadata.fetchAll()).thenAnswer((_) async => [row]);
    when(() => metadata.fetch(row.id)).thenAnswer((_) async => row);
    // Any server contact throws: the refusal must come before transport.
    final runtime = WalletNativeRuntime.open(
      catalog: TestWalletCatalog(metadata),
      reserved: _Reserved(),
      inputReservations: _NoInputReservations(),
      deleteCatalogEntry: (key) async {
        await metadata.delete(key.id);
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
    try {
      WalletSyncBinding.value(
        await runtime.create(WalletSyncBinding.keyFromMetadata(row)),
      );
      final result = await runtime.broadcast(
        WalletSyncBinding.keyFromMetadata(row),
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
