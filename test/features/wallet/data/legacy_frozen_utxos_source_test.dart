import 'dart:io';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/wallet/data/legacy_frozen_utxos_source.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SqliteDatabase db;
  late Directory dir;

  setUp(() {
    db = SqliteDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('legacy-freezes-');
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<void> insert(String walletId, String txId, int vout) => db
      .into(db.frozenUtxos)
      .insert(
        FrozenUtxosCompanion.insert(walletId: walletId, txId: txId, vout: vout),
      );

  test('sync imports every published row through the app table', () async {
    final a = 'a' * 64;
    final b = 'b' * 64;
    await insert('wpkh([0f36572d/84h/1h/0h])', a, 0);
    await insert('tr([0f36572d/86h/1h/0h])', a, 0);
    await insert('', b, 1);
    final sync = Sync.openForeground(
      documentsDirectory: dir.path,
      catalog: const _NoCatalog(),
      reservedAddresses: const _NoReserved(),
      legacyFreezes: LegacyFrozenUtxosSource(sqlite: db),
      inputReservations: _NoInputReservations(),
    );
    try {
      final listed = switch (await sync.coins.listFrozen()) {
        Ok(:final value) => value.toSet(),
        Err(:final failure) => fail(failure.logCode),
      };
      expect(listed, {
        FrozenOutpoint((
          txId: a,
          vout: 0,
        ), origin: 'wpkh([0f36572d/84h/1h/0h])'),
        FrozenOutpoint((txId: a, vout: 0), origin: 'tr([0f36572d/86h/1h/0h])'),
        FrozenOutpoint((txId: b, vout: 1), origin: ''),
      });
      // The published table stays intact.
      expect(await db.select(db.frozenUtxos).get(), hasLength(3));
    } finally {
      await sync.close();
    }
  });

  test('an unreadable database is a failure, not an empty table', () async {
    final file = File('${dir.path}/corrupt.sqlite')
      ..writeAsStringSync('not a database ' * 100);
    final corrupt = SqliteDatabase(NativeDatabase(file));
    try {
      final result = await LegacyFrozenUtxosSource(sqlite: corrupt).readAll();
      expect(result, isA<Err<List<FrozenOutpoint>, SyncFailure>>());
    } finally {
      await corrupt.close();
    }
  });
}

final class _NoCatalog implements WalletCatalogPort {
  const _NoCatalog();

  @override
  Future<Result<PublicWalletDescriptor, SyncFailure>> find(
    WalletKey key,
  ) async => const Err(SyncNotFoundFailure());

  @override
  Future<Result<List<PublicWalletDescriptor>, SyncFailure>> list() async =>
      const Ok([]);
}

final class _NoReserved implements ReservedAddressPort {
  const _NoReserved();

  @override
  Future<Result<bool, SyncFailure>> isReserved(
    WalletKey key,
    String address,
  ) async => const Ok(false);
}

final class _NoInputReservations implements InputReservationPort {
  @override
  Future<Result<List<InputReservation>, SyncFailure>> reservations() async =>
      const Ok([]);
}
