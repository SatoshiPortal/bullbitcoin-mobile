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

void main() {
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
