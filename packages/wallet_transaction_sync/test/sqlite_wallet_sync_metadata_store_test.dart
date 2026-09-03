import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';

void main() {
  late Directory directory;
  late String path;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('wallet-sync-metadata-');
    path = '${directory.path}/metadata.sqlite';
  });

  tearDown(() => directory.deleteSync(recursive: true));

  test('persists registration and metadata across reopen', () async {
    const registration = WalletSourceRegistration(
      key: WalletNetworkKey('wallet', 'bitcoin', 'testnet'),
      sourceKind: 'bdk',
      configurationFingerprint: 'config-hash',
    );
    final store = SqliteWalletSyncMetadataStore(databasePath: path);
    await store.writeRegistration(registration);
    store.close();
    final reopened = SqliteWalletSyncMetadataStore(databasePath: path);
    expect((await reopened.read(registration.key))!.registration, registration);
    expect(
      (await reopened.read(registration.key))!.registration.configuration,
      const OpaqueSourceConfiguration('persisted'),
    );
    reopened.close();
  });

  test('persists timestamps, success and receipt', () async {
    const registration = WalletSourceRegistration(
      key: WalletNetworkKey('w', 'c', 'n'),
      sourceKind: 's',
      configurationFingerprint: 'f',
    );
    final store = SqliteWalletSyncMetadataStore(databasePath: path);
    final attempted = DateTime.utc(2024, 1, 2, 3, 4, 5);
    final successful = DateTime.utc(2024, 1, 2, 3, 4, 6);
    await store.writeRegistration(registration);
    await store.writeAttempt(registration.key, attempted);
    await store.writeSuccess(registration.key, successful, 'content');
    await store.writeReceipt(
      WalletSyncReceipt(
        key: registration.key,
        successfulAt: successful,
        contentFingerprint: 'content',
      ),
    );
    final metadata = await store.read(registration.key);
    expect(metadata!.lastAttemptedSyncAt, attempted);
    expect(metadata.lastSuccessfulSyncAt, successful);
    expect(metadata.contentFingerprint, 'content');
    expect(
      (await store.readReceipt(registration.key))!.successfulAt,
      successful,
    );
    store.close();
  });

  test(
    'conflicting concurrent registrations retain exactly one identity',
    () async {
      const key = WalletNetworkKey('w', 'c', 'n');
      const first = WalletSourceRegistration(
        key: key,
        sourceKind: 'first',
        configurationFingerprint: 'a',
      );
      const second = WalletSourceRegistration(
        key: key,
        sourceKind: 'second',
        configurationFingerprint: 'b',
      );
      final left = SqliteWalletSyncMetadataStore(databasePath: path);
      final right = SqliteWalletSyncMetadataStore(databasePath: path);
      await Future.wait([
        left.writeRegistration(first),
        right.writeRegistration(second),
      ]);
      final stored = await left.read(key);
      expect(stored, isNotNull);
      expect([first, second].contains(stored!.registration), isTrue);
      expect(stored.registration.sourceKind, isNot(equals('')));
      left.close();
      right.close();
    },
  );

  test(
    'deletion marker survives reopen and clear removes metadata and receipt',
    () async {
      const key = WalletNetworkKey('w', 'c', 'n');
      const registration = WalletSourceRegistration(
        key: key,
        sourceKind: 's',
        configurationFingerprint: 'f',
      );
      final store = SqliteWalletSyncMetadataStore(databasePath: path);
      await store.writeRegistration(registration);
      await store.writeReceipt(
        WalletSyncReceipt(
          key: key,
          successfulAt: DateTime.utc(2024),
          contentFingerprint: 'f',
        ),
      );
      await store.writeDeletionMarker(key, WalletDeletionPhase.snapshotEvicted);
      store.close();
      final reopened = SqliteWalletSyncMetadataStore(databasePath: path);
      expect(
        (await reopened.read(key))!.deletionPhase,
        WalletDeletionPhase.snapshotEvicted,
      );
      expect(await reopened.readReceipt(key), isNotNull);
      await reopened.clear(key);
      expect(await reopened.read(key), isNull);
      expect(await reopened.readReceipt(key), isNull);
      reopened.close();
    },
  );

  test('does not store raw wallet-network identity', () async {
    const key = WalletNetworkKey(
      'wallet-id-sentinel',
      'chain-sentinel',
      'network-sentinel',
    );
    const registration = WalletSourceRegistration(
      key: key,
      sourceKind: 'bdk',
      configurationFingerprint:
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    );
    final store = SqliteWalletSyncMetadataStore(databasePath: path);
    await store.writeRegistration(registration);
    await store.writeSuccess(
      key,
      DateTime.utc(2024),
      'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
    );
    store.close();
    final bytes = File(path).readAsBytesSync();
    final text = String.fromCharCodes(Uint8List.fromList(bytes));
    for (final sentinel in [
      'wallet-id-sentinel',
      'chain-sentinel',
      'network-sentinel',
    ]) {
      expect(text, isNot(contains(sentinel)));
    }
  });

  test('rejects a future schema', () {
    SqliteWalletSyncMetadataStore(databasePath: path).close();
    final database = sqlite3.open(path);
    database.execute('PRAGMA user_version = 2');
    database.dispose();
    expect(
      () => SqliteWalletSyncMetadataStore(databasePath: path),
      throwsStateError,
    );
  });
}
