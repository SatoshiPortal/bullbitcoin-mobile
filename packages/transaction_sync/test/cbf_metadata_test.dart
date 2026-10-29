import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:transaction_sync/transaction_sync.dart';

void main() {
  test(
    'relay facts survive reopen, restaging, concurrent writers and schema rerun',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cbf-relay-metadata-',
      );
      final path = '${directory.path}/metadata.sqlite';
      const key = WalletNetworkKey('one', 'bitcoin', 'mainnet');
      const other = WalletNetworkKey('one', 'bitcoin', 'testnet');
      var store = await SqliteWalletSyncMetadataStore.open(databasePath: path);
      await store.stageCbfTransaction(key, 'spend');
      await store.writeCbfRelayState(key, 'spend', CbfRelayState.relayed);
      await store.stageCbfTransaction(key, 'uncertain');
      await store.writeCbfRelayState(
        key,
        'uncertain',
        CbfRelayState.submitting,
      );
      await store.stageCbfTransaction(other, 'spend');
      await store.close();
      // Replay schema initialization from the previous version over existing
      // tables: interrupted/repeated setup must preserve every relay fact.
      final db = sqlite3.open(path);
      db.execute('PRAGMA user_version = 3');
      db.dispose();
      store = await SqliteWalletSyncMetadataStore.open(databasePath: path);
      final concurrent = await SqliteWalletSyncMetadataStore.open(
        databasePath: path,
      );
      try {
        await Future.wait([
          store.stageCbfTransaction(key, 'spend'),
          concurrent.writeCbfRelayState(
            key,
            'spend',
            CbfRelayState.notBroadcast,
          ),
          concurrent.stageCbfTransaction(key, 'new-spend'),
        ]);
        expect(await store.readCbfRelayStates(key), {
          'spend': CbfRelayState.relayed,
          'uncertain': CbfRelayState.submitting,
          'new-spend': CbfRelayState.notBroadcast,
        });
        expect(await store.readCbfRelayStates(other), {
          'spend': CbfRelayState.notBroadcast,
        });
        await store.clear(key);
        expect(await concurrent.readCbfRelayStates(key), isEmpty);
        expect(await concurrent.readCbfRelayStates(other), isNotEmpty);
      } finally {
        await concurrent.close();
        await store.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('version 3 upgrades without inventing relay evidence', () async {
    final directory = await Directory.systemTemp.createTemp(
      'cbf-relay-upgrade-',
    );
    final path = '${directory.path}/metadata.sqlite';
    var store = await SqliteWalletSyncMetadataStore.open(databasePath: path);
    const key = WalletNetworkKey('one', 'bitcoin', 'mainnet');
    await store.completeCbfDiscovery(key, 'policy');
    await store.close();
    final db = sqlite3.open(path);
    db.execute('DROP TABLE wallet_cbf_relay');
    db.execute('PRAGMA user_version = 3');
    db.dispose();
    store = await SqliteWalletSyncMetadataStore.open(databasePath: path);
    expect(await store.isCbfDiscoveryComplete(key, 'policy'), isTrue);
    expect(await store.readCbfRelayStates(key), isEmpty);
    await store.close();
    await directory.delete(recursive: true);
  });

  test(
    'discovery marker survives reopen and is scoped to wallet and policy',
    () async {
      final directory = await Directory.systemTemp.createTemp('cbf-metadata-');
      final path = '${directory.path}/metadata.sqlite';
      const key = WalletNetworkKey('one', 'bitcoin', 'mainnet');
      const other = WalletNetworkKey('two', 'bitcoin', 'mainnet');
      var store = await SqliteWalletSyncMetadataStore.open(databasePath: path);
      expect(await store.isCbfDiscoveryComplete(key, 'policy-one'), isFalse);
      await store.completeCbfDiscovery(key, 'policy-one');
      await store.close();
      store = await SqliteWalletSyncMetadataStore.open(databasePath: path);
      expect(await store.isCbfDiscoveryComplete(key, 'policy-one'), isTrue);
      expect(await store.isCbfDiscoveryComplete(key, 'policy-two'), isFalse);
      expect(await store.isCbfDiscoveryComplete(other, 'policy-one'), isFalse);
      await store.clear(key);
      expect(await store.isCbfDiscoveryComplete(key, 'policy-one'), isFalse);
      await store.close();
      await directory.delete(recursive: true);
    },
  );
  test(
    'metadata v2 upgrade preserves registration and invents no discovery',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cbf-metadata-upgrade-',
      );
      final path = '${directory.path}/metadata.sqlite';
      const key = WalletNetworkKey('one', 'bitcoin', 'mainnet');
      const registration = WalletSourceRegistration(
        key: key,
        sourceKind: 'bdk_electrum',
        configurationFingerprint: 'public-fingerprint',
      );
      var store = await SqliteWalletSyncMetadataStore.open(databasePath: path);
      await store.writeRegistration(registration);
      await store.close();
      final db = sqlite3.open(path);
      db.execute('DROP TABLE wallet_cbf_discovery');
      db.execute('PRAGMA user_version = 2');
      db.dispose();
      store = await SqliteWalletSyncMetadataStore.open(databasePath: path);
      expect(
        (await store.read(key))?.registration.configurationFingerprint,
        'public-fingerprint',
      );
      expect(await store.isCbfDiscoveryComplete(key, 'policy'), isFalse);
      await store.close();
      await directory.delete(recursive: true);
    },
  );
}
