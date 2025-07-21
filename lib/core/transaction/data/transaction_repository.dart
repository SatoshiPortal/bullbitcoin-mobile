import 'dart:convert';

import 'package:bb_mobile/core/electrum/data/datasources/electrum_remote_datasource.dart'
    show ElectrumRemoteDatasource;
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/transactions_table.dart';
import 'package:bb_mobile/core/transaction/domain/entities/tx.dart';
import 'package:bb_mobile/locator.dart';

class TransactionRepository {
  final ElectrumRemoteDatasource _electrumRemoteDatasource;

  TransactionRepository({
    required ElectrumRemoteDatasource electrumRemoteDatasource,
  }) : _electrumRemoteDatasource = electrumRemoteDatasource;

  Future<RawBitcoinTxEntity> fetch({required String txid}) async {
    final sqlite = locator<SqliteDatabase>();
    final cachedTransaction =
        await sqlite.managers.transactions
            .filter((e) => e.txid(txid))
            .getSingleOrNull();

    if (cachedTransaction != null) {
      return TransactionModelExtension.toEntity(cachedTransaction);
    }

    // If not found in cache, fetch from Electrum
    final txBytes = await _electrumRemoteDatasource.getTransaction(txid);
    final tx = await RawBitcoinTxEntity.fromBytes(txBytes);

    // Cache the transaction
    await sqlite.managers.transactions.create(
      (t) => t(
        txid: tx.txid,
        version: tx.version,
        size: tx.size.toString(),
        vsize: tx.vsize.toString(),
        locktime: tx.locktime,
        vin: json.encode(tx.vin.map((e) => e.toJson()).toList()),
        vout: json.encode(tx.vout.map((e) => e.toJson()).toList()),
      ),
    );

    return tx;
  }
}
