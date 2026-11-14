import 'package:sync/src/data/datasources/spend_gate_store_datasource.dart';
import 'package:sync/src/data/read/persisted_wallet_readiness.dart';
import 'package:sync/src/data/native_store_paths.dart';
import 'package:sync/src/data/write/native_wallet_writer_repository.dart';
import 'package:sync/src/data/datasources/revision_store_datasource.dart';
import 'package:sync/src/data/sqlite_wallet_revision_reader.dart';
import 'dart:io';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';
import 'package:sync/read.dart';

import 'support/regtest_wallet.dart';
import 'package:sync/src/domain/native_network_policy.dart';

void main() {
  test(
    'native admission refuses unsupported chains and unscoped regtest ids',
    () {
      for (final network in <Network>[BitcoinNetwork.signet]) {
        expect(
          nativeKeyFailure(WalletKey(id: 'wallet:regtest', network: network)),
          isA<TransactionSyncUnsupportedNetworkFailure>(),
        );
      }
      expect(
        nativeKeyFailure(
          WalletKey(id: 'wallet:regtest', network: LiquidNetwork.regtest),
        ),
        isNull,
      );
      expect(
        nativeKeyFailure(
          WalletKey(id: 'origin', network: LiquidNetwork.regtest),
        ),
        isA<TransactionSyncInvalidCatalogFailure>(),
      );
      expect(
        nativeKeyFailure(
          WalletKey(id: 'origin', network: BitcoinNetwork.regtest),
        ),
        isA<TransactionSyncInvalidCatalogFailure>(),
      );
      expect(
        nativeKeyFailure(
          WalletKey(id: ':regtest', network: BitcoinNetwork.regtest),
        ),
        isA<TransactionSyncInvalidCatalogFailure>(),
      );
    },
  );

  test(
    'regtest native create, receive, reader and reopen preserve testnet',
    () async {
      final directory = Directory.systemTemp.createTempSync('regtest-native-');
      final descriptor = regtestDescriptor();
      final key = descriptor.key;
      final catalog = SingleWalletCatalog(descriptor);
      final metadataPath = revisionStorePath(directory.path);
      var revisions = RevisionStoreDatasource.openForeground(metadataPath);
      SpendGateStoreDatasource.provision(spendGateStorePath(directory.path));
      NativeWalletWriterRepository writer() => NativeWalletWriterRepository(
        revisions: revisions,
        reader: SqliteWalletRevisionReader(revisions),
        documentsDirectory: directory.path,
        catalog: catalog,
        reservedAddresses: NoReservedAddresses(),
      );
      final testnetPath = nativeWalletStoragePath(
        directory.path,
        WalletKey(
          id: key.id.replaceFirst(':regtest', ''),
          network: BitcoinNetwork.testnet,
        ),
      );
      final historical = File(testnetPath)
        ..writeAsStringSync('untouched historical store');
      try {
        expect(await writer().create(key, expectedGeneration: 0), isA<Ok>());
        final result = await writer().receive(key, expectedGeneration: 1);
        expect(result, isA<Ok>());
        final received =
            (result as Ok<ReceiveAddressIssued, TransactionSyncFailure>).value;
        expect(received.address.startsWith('bcrt1'), isTrue);
        final reader = WalletSnapshotReader(
          documentsDirectory: directory.path,
          readiness: PersistedWalletReadiness(revisions),
          requiredSchemaVersion: writerSchemaVersion,
          revisions: SqliteWalletRevisionReader(revisions),
          liquidAdmission: writer(),
        );
        final snapshot = await reader.bitcoin(descriptor);
        expect(snapshot, isA<Ok>());
        expect(
          (snapshot
                  as Ok<WalletReadSnapshot<bdk.Wallet>, TransactionSyncFailure>)
              .value
              .wallet
              .network(),
          bdk.Network.regtest,
        );
        revisions.close();
        revisions = RevisionStoreDatasource.openForeground(metadataPath);
        final reopened = await writer().receive(key, expectedGeneration: 1);
        expect(reopened, isA<Ok>());
        expect(
          (reopened as Ok<ReceiveAddressIssued, TransactionSyncFailure>)
              .value
              .address,
          received.address,
        );
        expect(historical.readAsStringSync(), 'untouched historical store');
        expect(await writer().delete(key, expectedGeneration: 1), isA<Ok>());
        expect(
          File(nativeWalletStoragePath(directory.path, key)).existsSync(),
          isFalse,
        );
        expect(historical.readAsStringSync(), 'untouched historical store');
      } finally {
        revisions.close();
        directory.deleteSync(recursive: true);
      }
    },
  );

  test(
    'regtest rejects legacy receive or change before creating a store',
    () async {
      final original = regtestDescriptor();
      for (final internal in [false, true]) {
        final directory = Directory.systemTemp.createTempSync(
          'regtest-refused-',
        );
        final descriptor = BitcoinWalletDescriptor(
          key: original.key,
          origin: original.origin,
          scriptType: ScriptType.bip84,
          externalDescriptor: internal
              ? original.externalDescriptor
              : 'sh(${original.externalDescriptor})',
          internalDescriptor: internal
              ? 'sh(${original.internalDescriptor})'
              : original.internalDescriptor,
        );
        final revisions = RevisionStoreDatasource.openForeground(
          revisionStorePath(directory.path),
        );
        SpendGateStoreDatasource.provision(spendGateStorePath(directory.path));
        final writer = NativeWalletWriterRepository(
          revisions: revisions,
          reader: SqliteWalletRevisionReader(revisions),
          documentsDirectory: directory.path,
          catalog: SingleWalletCatalog(descriptor),
          reservedAddresses: NoReservedAddresses(),
        );
        try {
          final result = await writer.create(
            descriptor.key,
            expectedGeneration: 0,
          );
          expect(result, isA<Err<WriterOutcome, TransactionSyncFailure>>());
          expect(
            (result as Err).failure,
            isA<TransactionSyncInvalidCatalogFailure>(),
          );
          expect(revisions.record(descriptor.key), isNull);
          expect(
            File(
              nativeWalletStoragePath(directory.path, descriptor.key),
            ).existsSync(),
            isFalse,
          );
        } finally {
          revisions.close();
          directory.deleteSync(recursive: true);
        }
      }
    },
  );
}
