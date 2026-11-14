import 'package:transaction_sync/src/write/lease_diagnostics.dart';
import 'package:transaction_sync/src/write/native_write_session.dart';
import 'package:transaction_sync/src/write/writer_diagnostics.dart';
import 'package:transaction_sync/src/write/writer_session.dart';
import 'dart:io';

import 'package:primitives/primitives.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:test/test.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:transaction_sync/write.dart';
import 'package:transaction_sync/src/write/revision_store.dart'
    show WriteIntent;

// Published BIP39 test-vector account, also pinned by wallet_identity_pins_test.
const _xpub =
    'xpub6BosfCnifzxcFwrSzQiqu2DBVTshkCXacvNsWGYJVVhhawA7d4R5WSWGFNbi8Aw6ZRc1brxMyWMzG3DSSSSoekkudhUd9yLb6qx39T9nMdj';
final _key = WalletKey(id: 'native-bdk', network: BitcoinNetwork.mainnet);
final _descriptor = BitcoinWalletDescriptor(
  key: _key,
  scriptType: ScriptType.bip84,
  origin: 'public-test-vector',
  externalDescriptor: 'wpkh($_xpub/0/*)',
  internalDescriptor: 'wpkh($_xpub/1/*)',
);

class _Catalog implements WalletCatalogPort {
  @override
  Future<Result<PublicWalletDescriptor, TransactionSyncFailure>> find(
    WalletKey key,
  ) async => Ok(_descriptor);
  @override
  Future<Result<List<PublicWalletDescriptor>, TransactionSyncFailure>>
  list() async => Ok([_descriptor]);
}

class _Reserved implements ReservedAddressPort {
  String? reserved;
  @override
  Future<Result<bool, TransactionSyncFailure>> isReserved(
    WalletKey key,
    String address,
  ) async => Ok(address == reserved);
}

class _Sync implements WriterSyncOperation {
  @override
  Future<Result<void, TransactionSyncFailure>> execute(
    PublicWalletDescriptor descriptor, {
    required int? issuedReceiveIndex,
  }) async => const Ok(null);
}

void main() {
  for (final interrupted in [false, true]) {
    test(
      'adoption preserves native high water through store loss; interrupted=$interrupted',
      () async {
        final dir = Directory.systemTemp.createTempSync('bdk-adoption-');
        final revisions = RevisionStore('${dir.path}/revisions.sqlite');
        final sessions = SdkWriteSessions(dir.path);
        final writer = NativeWalletWriter(
          lockDirectory: '${dir.path}/locks',
          revisions: revisions,
          documentsDirectory: dir.path,
          catalog: _Catalog(),
          reservedAddresses: _Reserved(),
        );
        try {
          final session = await sessions.open(_descriptor, create: true);
          await session.revealAndPersist(10);
          session.close();
          if (interrupted) revisions.begin(_key, WriteIntent.load);
          expect(
            await writer.create(
              _key,
              expectedGeneration: 0,
              existingOnly: true,
            ),
            isA<Ok>(),
          );
          // No receive between adoption and loss: that would mask the defect.
          final adoptedIndex = revisions.record(_key)?.issued;
          await sessions.delete(_key);
          expect(
            await writer.create(
              _key,
              expectedGeneration: 0,
              existingOnly: true,
            ),
            isA<Ok>(),
          );
          expect(
            await WriterSession.worker(
              lockDirectory: '${dir.path}/locks',
              revisions: revisions,
              sessions: sessions,
              descriptor: _descriptor,
              diagnostics: persistWriterDiagnostic,
              leaseScope: LeaseScope.compute,
            ).sync(_key, expectedGeneration: 0, operation: _Sync()),
            isA<Ok>(),
          );
          final result = await writer.receive(_key, expectedGeneration: 0);
          expect(result, isA<Ok>());
          expect(((result as Ok).value as ReceiveAddressIssued).index, 10);
          expect(adoptedIndex, 10);
        } finally {
          await revisions.close();
          dir.deleteSync(recursive: true);
        }
      },
    );
  }

  test('real BDK interrupted create, reserved skip, reopen and delete', () async {
    final directory = Directory.systemTemp.createTempSync('native-bdk-writer-');
    final metadataPath = '${directory.path}/revisions.sqlite';
    var revisions = RevisionStore(metadataPath);
    final reserved = _Reserved();
    NativeWalletWriter writer() => NativeWalletWriter(
      lockDirectory: '${directory.path}/locks',
      revisions: revisions,
      documentsDirectory: directory.path,
      catalog: _Catalog(),
      reservedAddresses: reserved,
    );
    try {
      // Process death after the persister opens but before Wallet construction.
      final staging =
          '${nativeWalletStoragePath(directory.path, _key)}.creating';
      revisions.begin(_key, WriteIntent.create);
      bdk.Persister.newSqlite(path: staging).dispose();

      expect(await writer().create(_key, expectedGeneration: 1), isA<Ok>());
      expect(File(staging).existsSync(), isFalse);
      final initial = await writer().receive(_key, expectedGeneration: 1);
      expect(initial, isA<Ok>());
      final first = (initial as Ok).value as ReceiveAddressIssued;
      expect(first.index, 0);
      reserved.reserved = first.address;
      final next = await writer().receive(_key, expectedGeneration: 1) as Ok;
      expect((next.value as ReceiveAddressIssued).index, 1);
      await revisions.close();
      revisions = RevisionStore(metadataPath);
      final reopened =
          await writer().receive(_key, expectedGeneration: 1) as Ok;
      expect(
        (reopened.value as ReceiveAddressIssued).address,
        (next.value as ReceiveAddressIssued).address,
      );
      expect(await writer().delete(_key, expectedGeneration: 1), isA<Ok>());
      expect(
        File(nativeWalletStoragePath(directory.path, _key)).existsSync(),
        isFalse,
      );
      final damaged = File(nativeWalletStoragePath(directory.path, _key));
      damaged.writeAsStringSync('not a wallet database');
      expect(await writer().create(_key, expectedGeneration: 2), isA<Err>());
      expect(damaged.readAsStringSync(), 'not a wallet database');
    } finally {
      await revisions.close();
      directory.deleteSync(recursive: true);
    }
  });
}
