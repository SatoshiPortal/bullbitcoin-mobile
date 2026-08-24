import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/send/data/models/pending_bitcoin_transaction_model.dart';
import 'package:drift/drift.dart';

class PendingBitcoinTransactionDatasource {
  final SqliteDatabase _database;

  const PendingBitcoinTransactionDatasource(this._database);

  Future<PendingBitcoinTransactionModel> save(
    PendingBitcoinTransactionModel model, {
    int? expectedRevision,
  }) async {
    final persistedModel = model.copyWith(
      createdAt: _sqliteDateTime(model.createdAt),
      updatedAt: _sqliteDateTime(model.updatedAt),
      revision: expectedRevision == null
          ? model.revision
          : expectedRevision + 1,
    );

    return _database.transaction(() async {
      final row = SendTransactionsCompanion.insert(
        id: persistedModel.id,
        walletId: persistedModel.walletId,
        stage: persistedModel.stage,
        label: Value(persistedModel.label),
        recipient: persistedModel.recipient,
        amount: persistedModel.amount,
        amountCurrencyCode: persistedModel.amountCurrencyCode,
        sendMax: persistedModel.sendMax,
        feeSelection: persistedModel.feeSelection,
        customFeeKind: Value(persistedModel.customFeeKind),
        customFeeValue: Value(persistedModel.customFeeValue),
        replaceByFee: persistedModel.replaceByFee,
        payjoinOptedOut: Value(persistedModel.payjoinOptedOut),
        psbt: Value(persistedModel.psbt),
        finalTransaction: Value(persistedModel.finalTransaction),
        createdAt: persistedModel.createdAt,
        updatedAt: persistedModel.updatedAt,
        revision: Value(persistedModel.revision),
      );
      if (expectedRevision == null) {
        await _database.into(_database.sendTransactions).insert(row);
      } else {
        final updated =
            await (_database.update(_database.sendTransactions)..where(
                  (stored) =>
                      stored.id.equals(persistedModel.id) &
                      stored.revision.equals(expectedRevision),
                ))
                .write(row);
        if (updated != 1) {
          throw const PendingBitcoinTransactionChangedException();
        }
      }
      await (_database.delete(
        _database.sendTransactionInputs,
      )..where((row) => row.transactionId.equals(persistedModel.id))).go();
      await (_database.delete(
        _database.sendTransactionPolicyChoices,
      )..where((row) => row.transactionId.equals(persistedModel.id))).go();
      for (final outpoint in persistedModel.selectedOutpoints) {
        final separator = outpoint.lastIndexOf(':');
        if (separator <= 0) throw const FormatException('Invalid outpoint');
        await _database
            .into(_database.sendTransactionInputs)
            .insert(
              SendTransactionInputsCompanion.insert(
                transactionId: persistedModel.id,
                txId: outpoint.substring(0, separator),
                vout: int.parse(outpoint.substring(separator + 1)),
              ),
            );
      }
      for (final entry in persistedModel.policyChoices.entries) {
        for (final optionIndex in entry.value) {
          await _database
              .into(_database.sendTransactionPolicyChoices)
              .insert(
                SendTransactionPolicyChoicesCompanion.insert(
                  transactionId: persistedModel.id,
                  node: entry.key,
                  optionIndex: optionIndex,
                ),
              );
        }
      }
      return persistedModel;
    });
  }

  Future<PendingBitcoinTransactionModel?> get(String id) async {
    return _database.transaction(() async {
      final row = await (_database.select(
        _database.sendTransactions,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      return row == null ? null : _withChildren(row);
    });
  }

  Stream<List<PendingBitcoinTransactionModel>> watchWallet(String walletId) {
    final query =
        _database.select(_database.sendTransactions).join([
            innerJoin(
              _database.walletMetadatas,
              _database.walletMetadatas.id.equalsExp(
                _database.sendTransactions.walletId,
              ),
            ),
          ])
          ..where(_database.sendTransactions.walletId.equals(walletId))
          ..orderBy([
            OrderingTerm.desc(_database.sendTransactions.updatedAt),
            OrderingTerm.desc(_database.sendTransactions.revision),
          ]);
    return query.watch().asyncMap(
      (_) => _database.transaction(() async {
        final rows = [
          for (final row in await query.get())
            row.readTable(_database.sendTransactions),
        ];
        return Future.wait(rows.map(_withChildren));
      }),
    );
  }

  Future<void> delete(String id, {required int expectedRevision}) async {
    final deleted =
        await (_database.delete(_database.sendTransactions)..where(
              (row) =>
                  row.id.equals(id) & row.revision.equals(expectedRevision),
            ))
            .go();
    if (deleted != 1) {
      throw const PendingBitcoinTransactionChangedException();
    }
  }

  Future<PendingBitcoinTransactionModel> _withChildren(
    SendTransactionRow row,
  ) async {
    final inputs = await (_database.select(
      _database.sendTransactionInputs,
    )..where((input) => input.transactionId.equals(row.id))).get();
    final choices = await (_database.select(
      _database.sendTransactionPolicyChoices,
    )..where((choice) => choice.transactionId.equals(row.id))).get();
    final policyChoices = <String, List<int>>{};
    for (final choice in choices) {
      (policyChoices[choice.node] ??= []).add(choice.optionIndex);
    }
    for (final value in policyChoices.values) {
      value.sort();
    }
    return PendingBitcoinTransactionModel(
      id: row.id,
      walletId: row.walletId,
      stage: row.stage,
      label: row.label,
      recipient: row.recipient,
      amount: row.amount,
      amountCurrencyCode: row.amountCurrencyCode,
      sendMax: row.sendMax,
      feeSelection: row.feeSelection,
      customFeeKind: row.customFeeKind,
      customFeeValue: row.customFeeValue,
      replaceByFee: row.replaceByFee,
      payjoinOptedOut: row.payjoinOptedOut,
      selectedOutpoints: {
        for (final input in inputs) '${input.txId}:${input.vout}',
      },
      policyChoices: policyChoices,
      psbt: row.psbt,
      finalTransaction: row.finalTransaction,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      revision: row.revision,
    );
  }
}

DateTime _sqliteDateTime(DateTime value) {
  final milliseconds = value.millisecondsSinceEpoch;
  return DateTime.fromMillisecondsSinceEpoch(
    milliseconds - milliseconds % Duration.millisecondsPerSecond,
    isUtc: true,
  );
}

final class PendingBitcoinTransactionChangedException implements Exception {
  const PendingBitcoinTransactionChangedException();
}
