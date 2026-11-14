import 'dart:io';

import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart'
    show Signer;
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/features/wallet/data/wallet_catalog_port_impl.dart';
import 'package:bb_mobile/features/wallet/data/wallet_native_runtime.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/read.dart';
import 'package:transaction_sync/write.dart';
import 'package:transaction_sync/transaction_sync.dart';

class _Metadata extends Mock implements WalletMetadataDatasource {}

class _Reserved implements ReservedAddressPort {
  @override
  Future<Result<bool, TransactionSyncFailure>> isReserved(
    WalletKey key,
    String address,
  ) async => const Ok(false);
}

class _Offline implements WalletConnectionPolicy {
  @override
  Future<Result<T, TransactionSyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, TransactionSyncFailure>> Function(
      WalletConnection,
    )
    operation,
    required bool Function(TransactionSyncFailure) mayRetry,
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
      RevisionStore? abandoned;
      var attempts = 0;
      final runtime = WalletNativeRuntime(
        catalog: WalletCatalogPortImpl(metadata),
        reserved: _Reserved(),
        metadata: metadata,
        sync: ElectrumSync(
          connections: _Offline(),
          documentsDirectory: () async => directory.path,
        ),
        documentsDirectory: () async => directory.path,
        onRevisionStoreOpened: (store) {
          if (++attempts == 1) {
            abandoned = store;
            throw const FileSystemException('assembly interrupted');
          }
        },
      );
      try {
        await runtime.initialize();
        final failedStore = abandoned;
        expect(failedStore, isNotNull);
        if (failedStore == null) return;
        await expectLater(
          failedStore.read(
            WalletKey(id: 'probe', network: BitcoinNetwork.testnet),
          ),
          throwsStateError,
        );
        await runtime.initialize();
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
      final runtime = WalletNativeRuntime(
        catalog: WalletCatalogPortImpl(metadata),
        reserved: _Reserved(),
        metadata: metadata,
        sync: ElectrumSync(
          connections: _Offline(),
          documentsDirectory: () async => directory.path,
        ),
        documentsDirectory: () async {
          if (++attempts == 1) throw const FileSystemException('unavailable');
          return directory.path;
        },
      );
      try {
        await runtime.initialize();
        await runtime.initialize();
        expect(attempts, 2);
      } finally {
        await runtime.close();
        directory.deleteSync(recursive: true);
      }
    },
  );
  test(
    'offline create, issued address, read and tombstone survive reopening',
    () async {
      final directory = Directory.systemTemp.createTempSync('native-runtime-');
      final mnemonic = bdk.Mnemonic.fromString(
        mnemonic:
            'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
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
      when(
        () => metadata.fetchAll(),
      ).thenAnswer((_) async => rows.values.toList());
      when(() => metadata.fetch(row.id)).thenAnswer((_) async => rows[row.id]);
      when(() => metadata.delete(row.id)).thenAnswer((_) async {
        rows.remove(row.id);
      });
      WalletNativeRuntime open() => WalletNativeRuntime(
        catalog: WalletCatalogPortImpl(metadata),
        reserved: _Reserved(),
        metadata: metadata,
        sync: ElectrumSync(
          connections: _Offline(),
          documentsDirectory: () async => directory.path,
        ),
        documentsDirectory: () async => directory.path,
      );
      var runtime = open();
      try {
        final unfinished = row.copyWith(
          externalPublicDescriptor: 'wpkh(invalid)',
        );
        rows[row.id] = unfinished;
        await expectLater(
          runtime.create(unfinished),
          throwsA(isA<WalletSnapshotException>()),
        );
        expect(rows[row.id], unfinished);
        rows[row.id] = row;
        await runtime.create(row);
        await runtime.initialize();
        var address = await runtime.receive(row);
        final wallet = await runtime.bitcoin(WalletModel.fromMetadata(row));
        expect(wallet.balance().total.toSat(), 0);
        final revisions = <WalletRevisionState>[];
        final observation = runtime.changes.listen(revisions.add);
        final other = open();
        await other.initialize();
        address = await other.receive(row, advance: true);
        await other.close();
        await pumpEventQueue();
        expect(revisions, isEmpty);
        await runtime.refreshAll();
        await pumpEventQueue();
        expect(revisions, hasLength(1));
        expect(revisions.single.lifecycle, WalletLifecycle.active);
        await observation.cancel();

        await runtime.close();
        runtime = open();
        await runtime.initialize();
        expect(await runtime.receive(row), address);
        final advanced = await runtime.receive(row, advance: true);
        expect(await runtime.issuedReceiveIndex(row), advanced.index);
        expect(advanced.index, address.index + 1);
        await runtime.close();
        final missing = row.copyWith(id: 'wpkh([11223344/84h/1h/0h])');
        rows[missing.id] = missing;
        when(
          () => metadata.fetch(missing.id),
        ).thenAnswer((_) async => rows[missing.id]);
        final missingKey =
            (WalletCatalogPortImpl.descriptorFromMetadata(missing)
                    as Ok<PublicWalletDescriptor, TransactionSyncFailure>)
                .value
                .key;
        final missingStore = File(
          nativeWalletStoragePath(directory.path, missingKey),
        );
        final metadataFile = File(writerMetadataPath(directory.path));
        metadataFile.writeAsStringSync('corrupt revision metadata');
        runtime = open();
        // A global catalog failure leaves recovery pending across a restart.
        when(
          () => metadata.fetchAll(),
        ).thenThrow(const FileSystemException('catalog unavailable'));
        await runtime.initialize();
        final recoveryMarker = File('${metadataFile.path}.recovery');
        expect(recoveryMarker.existsSync(), isTrue);
        await runtime.close();
        when(
          () => metadata.fetchAll(),
        ).thenAnswer((_) async => rows.values.toList());
        runtime = open();
        await runtime.initialize();
        expect(missingStore.existsSync(), isFalse);
        final healthyKey =
            (WalletCatalogPortImpl.descriptorFromMetadata(row)
                    as Ok<PublicWalletDescriptor, TransactionSyncFailure>)
                .value
                .key;
        final beforeReads = await runtime.readRevision(healthyKey) as Ok;
        clearInteractions(metadata);
        for (var i = 0; i < 5; i++) {
          await runtime.bitcoin(WalletModel.fromMetadata(row));
          await expectLater(
            runtime.bitcoin(WalletModel.fromMetadata(missing)),
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
        await runtime.resumeProvisioning();
        expect(
          missingStore.existsSync(),
          isTrue,
          reason: 'a completed adoption pass permits explicit provisioning',
        );
        await runtime.close();
        runtime = open();
        await runtime.initialize();
        expect(
          await runtime.bitcoin(WalletModel.fromMetadata(missing)),
          isA<bdk.Wallet>(),
        );
        rows.remove(missing.id);
        final adopted = await runtime.bitcoin(WalletModel.fromMetadata(row));
        expect(adopted.balance().total.toSat(), 0);
        expect(
          metadataFile.parent.listSync().where(
            (file) => file.path.contains('.corrupt-'),
          ),
          isNotEmpty,
        );
        await runtime.delete(row);
        await expectLater(
          runtime.bitcoin(WalletModel.fromMetadata(row)),
          throwsA(isA<WalletSnapshotException>()),
        );
        // Simulate crash after writer.delete and before catalog deletion.
        expect(rows, isNotEmpty);
        await runtime.close();
        runtime = open();
        await runtime.initialize();
        expect(rows, isEmpty);
        verify(() => metadata.delete(row.id)).called(1);
        // Re-import is interrupted after its catalog row becomes visible.
        await runtime.prepareCreate(row);
        rows[row.id] = row;
        await runtime.close();
        runtime = open();
        await runtime.initialize();
        expect(rows[row.id], row);
        expect(
          await runtime.bitcoin(WalletModel.fromMetadata(row)),
          isA<bdk.Wallet>(),
        );
        // If corruption destroys a deletion tombstone before catalog removal,
        // the surviving row is indistinguishable from an interrupted import.
        await runtime.delete(row);
        await runtime.close();
        metadataFile.writeAsStringSync('corrupt deletion metadata');
        runtime = open();
        await runtime.initialize();
        await expectLater(
          runtime.bitcoin(WalletModel.fromMetadata(row)),
          throwsA(isA<WalletSnapshotException>()),
        );
        expect(recoveryMarker.existsSync(), isFalse);
        await runtime.resumeProvisioning();
        expect(
          await runtime.bitcoin(WalletModel.fromMetadata(row)),
          isA<bdk.Wallet>(),
          reason:
              'documented residual: lost deletion metadata permits reappearance',
        );
      } finally {
        await runtime.close();
        directory.deleteSync(recursive: true);
      }
    },
  );
}
