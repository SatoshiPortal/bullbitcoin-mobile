import 'dart:io';

import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart'
    show Signer;
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/features/wallet/data/wallet_catalog_port_impl.dart';
import 'package:bb_mobile/features/wallet/data/wallet_native_runtime.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/read.dart';
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
      } finally {
        await runtime.close();
        directory.deleteSync(recursive: true);
      }
    },
  );
}
