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

  Future<int> revision() async =>
      (await db.select(db.walletBackupStates).getSingleOrNull())
          ?.localRevision ??
      0;

  group('FrozenWalletUtxoDatasource', () {
    test(
      'freeze and unfreeze record durable changes, but no-ops do not',
      () async {
        await datasource.freezeOutpoints(
          walletId: walletId,
          outpoints: const [a, b],
        );
        expect(await revision(), 1);
        await datasource.freezeOutpoints(
          walletId: walletId,
          outpoints: const [a],
        );
        expect(await revision(), 1);
        await datasource.unfreezeOutpoints(
          walletId: walletId,
          outpoints: const [a],
        );
        expect(await revision(), 2);
        await datasource.unfreezeOutpoints(
          walletId: walletId,
          outpoints: const [a],
        );
        expect(await revision(), 2);
      },
    );

    test('restored freezes record changes only once', () async {
      const outpoints = [(walletId: walletId, txId: 'aaaa', vout: 0)];
      await datasource.restoreFrozenWalletOutpoints(outpoints);
      expect(await revision(), 1);
      await datasource.restoreFrozenWalletOutpoints(outpoints);
      expect(await revision(), 1);
    });

    for (final operation in ['freeze', 'restore', 'unfreeze']) {
      test(
        '$operation rolls back if its backup revision cannot commit',
        () async {
          if (operation == 'unfreeze') {
            await datasource.freezeOutpoints(
              walletId: walletId,
              outpoints: const [a],
            );
          }
          final before = await datasource.getAllFrozen();
          final previousRevision = await revision();
          var notifications = 0;
          final subscription = datasource.changes.listen(
            (_) => notifications++,
          );
          addTearDown(subscription.cancel);
          await db.customStatement('''
          CREATE TRIGGER reject_freeze_backup_revision
          BEFORE UPDATE OF local_revision ON wallet_backup_states
          BEGIN SELECT RAISE(ABORT, 'injected revision failure'); END
        ''');
          final write = switch (operation) {
            'freeze' => datasource.freezeOutpoints(
              walletId: walletId,
              outpoints: const [a],
            ),
            'restore' => datasource.restoreFrozenWalletOutpoints(const [
              (walletId: walletId, txId: 'aaaa', vout: 0),
            ]),
            _ => datasource.unfreezeOutpoints(
              walletId: walletId,
              outpoints: const [a],
            ),
          };
          await expectLater(write, throwsA(isA<Exception>()));
          expect(await datasource.getAllFrozen(), before);
          expect(await revision(), previousRevision);
          expect(notifications, 0);
        },
      );
    }

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
        expect(all.toSet(), {
          (walletId: walletId, txId: a.txId, vout: a.vout),
          (walletId: 'wallet-2', txId: b.txId, vout: b.vout),
        });
      },
    );
  });
}
