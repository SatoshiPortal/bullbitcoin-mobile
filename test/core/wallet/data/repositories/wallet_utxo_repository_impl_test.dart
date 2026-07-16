import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_utxo_repository_impl.dart';
import 'package:bb_mobile/core/wallet/domain/entities/frozen_wallet_outpoint.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _MockLabelsFacade extends Mock implements LabelsFacade {}

class _MockBdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _MockLwkWalletDatasource extends Mock implements LwkWalletDatasource {}

void main() {
  test(
    'domain export preserves attribution and idempotent frozen rows',
    () async {
      final database = SqliteDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final frozen = FrozenWalletUtxoDatasource(db: database);
      final repository = WalletUtxoRepositoryImpl(
        walletMetadataDatasource: _MockWalletMetadataDatasource(),
        labelsFacade: _MockLabelsFacade(),
        bdkWalletDatasource: _MockBdkWalletDatasource(),
        lwkWalletDatasource: _MockLwkWalletDatasource(),
        frozenWalletUtxoDatasource: frozen,
      );
      final txId = 'a' * 64;
      final outpoint = (txId: txId, vout: 2);

      await repository.freezeUtxos(
        walletId: 'elwpkh([0f36572d/84h/1h/0h])',
        outpoints: [outpoint],
      );
      await repository.freezeUtxos(
        walletId: 'elwpkh([0f36572d/84h/1h/0h])',
        outpoints: [outpoint],
      );

      final rows = await repository.getAllFrozenWalletOutpoints();

      expect(rows, hasLength(1));
      expect(rows.single.walletId, 'elwpkh([0f36572d/84h/1h/0h])');
      expect(rows.single.outpoint, outpoint);
    },
  );

  test('domain export preserves an empty imported attribution', () async {
    final database = SqliteDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final frozen = FrozenWalletUtxoDatasource(db: database);
    final repository = WalletUtxoRepositoryImpl(
      walletMetadataDatasource: _MockWalletMetadataDatasource(),
      labelsFacade: _MockLabelsFacade(),
      bdkWalletDatasource: _MockBdkWalletDatasource(),
      lwkWalletDatasource: _MockLwkWalletDatasource(),
      frozenWalletUtxoDatasource: frozen,
    );
    final txId = 'b' * 64;

    await frozen.freezeOutpoints(
      walletId: '',
      outpoints: [(txId: txId, vout: 0)],
    );

    final row = (await repository.getAllFrozenWalletOutpoints()).single;

    expect(row.walletId, isEmpty);
    expect(row.isAttributed, isFalse);
  });

  test('recovery atomically preserves exact distinct attributions', () async {
    final database = SqliteDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = WalletUtxoRepositoryImpl(
      walletMetadataDatasource: _MockWalletMetadataDatasource(),
      labelsFacade: _MockLabelsFacade(),
      bdkWalletDatasource: _MockBdkWalletDatasource(),
      lwkWalletDatasource: _MockLwkWalletDatasource(),
      frozenWalletUtxoDatasource: FrozenWalletUtxoDatasource(db: database),
    );
    final restored = [
      FrozenWalletOutpoint(walletId: '', txId: 'c' * 64, vout: 1),
      FrozenWalletOutpoint(
        walletId: 'elwpkh([0f36572d/84h/1h/0h])',
        txId: 'c' * 64,
        vout: 1,
      ),
    ];

    await repository.restoreFrozenWalletOutpoints(restored);
    await repository.restoreFrozenWalletOutpoints(restored);
    final rows = await repository.getAllFrozenWalletOutpoints();

    expect(rows, hasLength(2));
    expect(
      rows.map((row) => row.walletId),
      containsAll(['', restored[1].walletId]),
    );
  });

  test('emits post-commit freeze changes but ignores empty writes', () async {
    final database = SqliteDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final frozen = FrozenWalletUtxoDatasource(db: database);
    final repository = WalletUtxoRepositoryImpl(
      walletMetadataDatasource: _MockWalletMetadataDatasource(),
      labelsFacade: _MockLabelsFacade(),
      bdkWalletDatasource: _MockBdkWalletDatasource(),
      lwkWalletDatasource: _MockLwkWalletDatasource(),
      frozenWalletUtxoDatasource: frozen,
    );
    var changes = 0;
    final subscription = repository.freezeChanges.listen((_) => changes++);
    addTearDown(subscription.cancel);
    final outpoint = (txId: 'd' * 64, vout: 2);

    await repository.freezeUtxos(walletId: 'wallet', outpoints: const []);
    expect(changes, 0);

    await repository.freezeUtxos(walletId: 'wallet', outpoints: [outpoint]);
    await repository.unfreezeUtxos(walletId: 'wallet', outpoints: [outpoint]);

    expect(changes, 2);
  });
}
