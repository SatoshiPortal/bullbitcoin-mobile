import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SqliteDatabase db;
  late FrozenWalletUtxoDatasource datasource;

  const walletId = 'wallet-1';
  const a = (txId: 'aaaa', vout: 0);
  const b = (txId: 'bbbb', vout: 1);
  const c = (txId: 'cccc', vout: 2);

  setUp(() {
    db = SqliteDatabase(NativeDatabase.memory());
    datasource = FrozenWalletUtxoDatasource(db: db);
  });

  tearDown(() async => db.close());

  group('FrozenWalletUtxoDatasource', () {
    test('freeze → read → unfreeze round trip', () async {
      await datasource.freezeOutpoints(
        walletId: walletId,
        outpoints: const [a, b],
      );

      final frozen = await datasource.getFrozenOutpoints(walletId: walletId);
      expect(frozen.toSet(), {a, b});

      await datasource.unfreezeOutpoints(
        walletId: walletId,
        outpoints: const [a],
      );

      final after = await datasource.getFrozenOutpoints(walletId: walletId);
      expect(after, [b]);
    });

    test('freeze is idempotent (upsert, no duplicate rows)', () async {
      await datasource.freezeOutpoints(
        walletId: walletId,
        outpoints: const [a],
      );
      await datasource.freezeOutpoints(
        walletId: walletId,
        outpoints: const [a],
      );

      final frozen = await datasource.getFrozenOutpoints(walletId: walletId);
      expect(frozen, [a]);
    });

    test('empty outpoints is a no-op for freeze and unfreeze', () async {
      await datasource.freezeOutpoints(walletId: walletId, outpoints: const []);
      expect(await datasource.getFrozenOutpoints(walletId: walletId), isEmpty);

      await datasource.freezeOutpoints(
        walletId: walletId,
        outpoints: const [a],
      );
      await datasource.unfreezeOutpoints(
        walletId: walletId,
        outpoints: const [],
      );
      expect(await datasource.getFrozenOutpoints(walletId: walletId), [a]);
    });

    test('frozen outpoints are scoped per wallet', () async {
      await datasource.freezeOutpoints(
        walletId: walletId,
        outpoints: const [a],
      );
      await datasource.freezeOutpoints(
        walletId: 'wallet-2',
        outpoints: const [b],
      );

      expect(await datasource.getFrozenOutpoints(walletId: walletId), [a]);
      expect(await datasource.getFrozenOutpoints(walletId: 'wallet-2'), [b]);
    });

    test('batch freeze writes all-or-nothing across many outpoints', () async {
      await datasource.freezeOutpoints(
        walletId: walletId,
        outpoints: const [a, b, c],
      );

      final frozen = await datasource.getFrozenOutpoints(walletId: walletId);
      expect(frozen.toSet(), {a, b, c});
    });

    test(
      'unfreeze is by outpoint — clears a row attributed to any walletId',
      () async {
        // A BIP329-imported freeze stored unattributed ('') or under a sibling
        // origin must still be unfreezable from the owning wallet's view, else
        // the coin shows frozen but can never be cleared.
        await datasource.freezeOutpoints(walletId: '', outpoints: const [a]);
        await datasource.freezeOutpoints(
          walletId: 'wallet-other',
          outpoints: const [b],
        );

        await datasource.unfreezeOutpoints(
          walletId: walletId,
          outpoints: const [a, b],
        );

        expect(await datasource.getAllFrozen(), isEmpty);
      },
    );

    test(
      'getAllFrozen returns every row across wallets, tagged by walletId',
      () async {
        await datasource.freezeOutpoints(
          walletId: walletId,
          outpoints: const [a],
        );
        await datasource.freezeOutpoints(
          walletId: 'wallet-2',
          outpoints: const [b],
        );

        final all = await datasource.getAllFrozen();
        expect(
          all
              .map(
                (item) =>
                    (walletId: item.walletId, txId: item.txId, vout: item.vout),
              )
              .toSet(),
          {
            (walletId: walletId, txId: a.txId, vout: a.vout),
            (walletId: 'wallet-2', txId: b.txId, vout: b.vout),
          },
        );
      },
    );
  });
}
