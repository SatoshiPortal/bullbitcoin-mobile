import 'dart:async';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/send/data/pending_bitcoin_transaction_datasource.dart';
import 'package:bb_mobile/features/send/data/models/pending_bitcoin_transaction_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SqliteDatabase database;
  late PendingBitcoinTransactionDatasource datasource;

  setUp(() async {
    database = SqliteDatabase(NativeDatabase.memory());
    datasource = PendingBitcoinTransactionDatasource(database);
    await database
        .into(database.walletMetadatas)
        .insert(
          WalletMetadatasCompanion.insert(
            id: 'wallet-id',
            network: Network.bitcoinTestnet,
            isEncryptedVaultTested: false,
            isPhysicalBackupTested: false,
            publicDescriptor: 'wpkh(tpub/<0;1>/*)#descriptor',
            isDefault: false,
          ),
        );
  });

  tearDown(() => database.close());

  test('stores and replaces normalized inputs and policy choices', () async {
    final transaction = _transaction();

    await datasource.save(transaction);
    final stored = await datasource.get(transaction.id);

    expect(stored?.selectedOutpoints, transaction.selectedOutpoints);
    expect(stored?.policyChoices, transaction.policyChoices);

    final savedUpdate = await datasource.save(
      _transaction(
        updatedAt: DateTime.utc(2026, 8, 14, 1, 0, 0, 500),
        selectedOutpoints: {'replacement:3'},
        policyChoices: {
          'replacement-node': [2],
        },
      ),
      expectedRevision: 0,
    );
    final updated = await datasource.get(transaction.id);

    expect(updated?.selectedOutpoints, {'replacement:3'});
    expect(updated?.policyChoices, {
      'replacement-node': [2],
    });
    expect(savedUpdate.updatedAt, DateTime.utc(2026, 8, 14, 1));
    expect(savedUpdate.revision, 1);
    expect(updated?.updatedAt, savedUpdate.updatedAt);
    expect(
      await database.select(database.sendTransactionInputs).get(),
      hasLength(1),
    );
    expect(
      await database.select(database.sendTransactionPolicyChoices).get(),
      hasLength(1),
    );
  });

  test('rejects a stale update without replacing newer data', () async {
    final original = _transaction();
    final newer = _transaction(
      updatedAt: DateTime.utc(2026, 8, 14, 2),
      selectedOutpoints: {'newer:0'},
    );
    await datasource.save(original);
    await datasource.save(newer, expectedRevision: 0);

    await expectLater(
      datasource.save(
        _transaction(
          updatedAt: DateTime.utc(2026, 8, 14, 3),
          selectedOutpoints: {'stale:0'},
        ),
        expectedRevision: 0,
      ),
      throwsA(isA<PendingBitcoinTransactionChangedException>()),
    );

    expect((await datasource.get(original.id))?.selectedOutpoints, {'newer:0'});
  });

  test('rejects a stale delete without removing newer data', () async {
    await datasource.save(_transaction());
    await datasource.save(
      _transaction(updatedAt: DateTime.utc(2026, 8, 14, 2)),
      expectedRevision: 0,
    );

    await expectLater(
      datasource.delete('pending-id', expectedRevision: 0),
      throwsA(isA<PendingBitcoinTransactionChangedException>()),
    );
    expect(await datasource.get('pending-id'), isNotNull);

    await datasource.delete('pending-id', expectedRevision: 1);
    expect(await datasource.get('pending-id'), isNull);
  });

  test('deletes pending transactions with their wallet', () async {
    final emissions = StreamIterator(datasource.watchWallet('wallet-id'));
    addTearDown(emissions.cancel);

    expect(await emissions.moveNext(), isTrue);
    expect(emissions.current, isEmpty);

    await datasource.save(_transaction());
    expect(await emissions.moveNext(), isTrue);
    expect(emissions.current, hasLength(1));

    await database.delete(database.walletMetadatas).go();
    expect(await emissions.moveNext(), isTrue);
    expect(emissions.current, isEmpty);

    expect(await database.select(database.sendTransactions).get(), isEmpty);
    expect(
      await database.select(database.sendTransactionInputs).get(),
      isEmpty,
    );
    expect(
      await database.select(database.sendTransactionPolicyChoices).get(),
      isEmpty,
    );
  });
}

PendingBitcoinTransactionModel _transaction({
  DateTime? updatedAt,
  Set<String> selectedOutpoints = const {'transaction:0', 'transaction:1'},
  Map<String, List<int>> policyChoices = const <String, List<int>>{
    'threshold': <int>[0, 1],
  },
}) => PendingBitcoinTransactionModel(
  id: 'pending-id',
  walletId: 'wallet-id',
  stage: 'needsSignatures',
  label: 'Shared payment',
  recipient: 'tb1qrecipient',
  amount: '50000',
  amountCurrencyCode: 'sats',
  sendMax: false,
  feeSelection: 'fastest',
  replaceByFee: true,
  selectedOutpoints: selectedOutpoints,
  policyChoices: policyChoices,
  psbt: 'cHNidP8=',
  createdAt: DateTime.utc(2026, 8, 14),
  updatedAt: updatedAt ?? DateTime.utc(2026, 8, 14, 1),
);
