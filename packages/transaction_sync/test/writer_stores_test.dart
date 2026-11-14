import 'dart:io';

import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:transaction_sync/src/data/native_store_paths.dart';
import 'package:transaction_sync/src/data/write/writer_lock.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:transaction_sync/write.dart';

final class _Catalog implements WalletCatalogPort {
  @override
  Future<Result<PublicWalletDescriptor, TransactionSyncFailure>> find(
    WalletKey key,
  ) async => const Err(TransactionSyncNotFoundFailure());
  @override
  Future<Result<List<PublicWalletDescriptor>, TransactionSyncFailure>>
  list() async => const Ok([]);
}

final class _Reserved implements ReservedAddressPort {
  @override
  Future<Result<bool, TransactionSyncFailure>> isReserved(
    WalletKey key,
    String address,
  ) async => const Ok(false);
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('writer-stores-'));
  tearDown(() => dir.deleteSync(recursive: true));

  ForegroundStores foreground() => openForeground(
    documentsDirectory: dir.path,
    catalog: _Catalog(),
    reservedAddresses: _Reserved(),
  );

  int userVersion(String path) {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      return db.userVersion;
    } finally {
      db.dispose();
    }
  }

  test('the foreground creates both stores before any pass', () async {
    final stores = foreground();
    try {
      expect(userVersion(revisionStorePath(dir.path)), 1);
      expect(userVersion(spendGateStorePath(dir.path)), 1);
      expect(
        File('${spendGateStorePath(dir.path)}.provisioned').existsSync(),
        isTrue,
      );
      expect(stores.recoveredMetadata, isFalse);
    } finally {
      await stores.close();
    }
    // A second opening is no migration: the existing stores are kept.
    final again = foreground();
    await again.close();
    expect(userVersion(revisionStorePath(dir.path)), 1);
  });

  test('opening existing stores never creates them', () {
    expect(
      () => openExisting(dir.path),
      throwsA(isA<RevisionStoreUnavailable>()),
    );
    expect(dir.listSync(), isEmpty);
  });

  for (final (name, version) in [('older', 0), ('newer', 2)]) {
    test('opening existing stores refuses a $name layout unchanged', () {
      final path = revisionStorePath(dir.path);
      File(path).parent.createSync(recursive: true);
      final db = sqlite3.open(path);
      db.execute('CREATE TABLE revisions (wallet TEXT, network TEXT)');
      db.userVersion = version;
      db.dispose();
      final before = File(path).readAsBytesSync();
      expect(
        () => openExisting(dir.path),
        throwsA(isA<RevisionStoreUnavailable>()),
      );
      expect(File(path).readAsBytesSync(), before);
      expect(userVersion(path), version);
    });
  }

  test(
    'unreadable metadata is quarantined and spending waits for recovery',
    () async {
      final path = revisionStorePath(dir.path);
      File(path).parent.createSync(recursive: true);
      File(path).writeAsStringSync('not a database');
      final stores = foreground();
      try {
        expect(stores.recoveredMetadata, isTrue);
        expect(File(recoveryMarkerPath(dir.path)).existsSync(), isTrue);
        expect(
          File(
            path,
          ).parent.listSync().where((f) => f.path.contains('.corrupt-')),
          isNotEmpty,
        );
        final key = WalletKey(id: 'w', network: BitcoinNetwork.testnet);
        expect(
          await stores.spendGate.check(key),
          BitcoinSpendStatus.unavailable,
        );
        stores.completeRecovery();
        expect(stores.recoveredMetadata, isFalse);
        expect(File(recoveryMarkerPath(dir.path)).existsSync(), isFalse);
      } finally {
        await stores.close();
      }
    },
  );

  test('two keys resolving to one native store share one lock', () {
    final mainnet = WalletKey(id: 'same', network: BitcoinNetwork.mainnet);
    final testnet = WalletKey(id: 'same', network: BitcoinNetwork.testnet);
    final liquid = WalletKey(id: 'same', network: LiquidNetwork.mainnet);
    expect(
      nativeWalletStoragePath(dir.path, mainnet),
      nativeWalletStoragePath(dir.path, testnet),
    );
    expect(
      (writerLockPath(dir.path, mainnet) as Ok).value,
      (writerLockPath(dir.path, testnet) as Ok).value,
    );
    final held =
        WriterLock.acquire(dir.path, mainnet)
            as Ok<WriterLock, TransactionSyncFailure>;
    try {
      expect(
        (WriterLock.acquire(dir.path, testnet) as Err).failure,
        isA<TransactionSyncBusyFailure>(),
      );
      // A different native store keeps its own lock.
      final other =
          WriterLock.acquire(dir.path, liquid)
              as Ok<WriterLock, TransactionSyncFailure>;
      other.value.release();
    } finally {
      held.value.release();
    }
  });

  test('an unsupported key is refused before any lock path exists', () {
    final signet = WalletKey(id: 'w', network: BitcoinNetwork.signet);
    expect(
      (WriterLock.acquire(dir.path, signet) as Err).failure,
      isA<TransactionSyncUnsupportedNetworkFailure>(),
    );
    expect(dir.listSync(), isEmpty);
  });
}
