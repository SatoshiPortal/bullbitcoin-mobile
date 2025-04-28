import 'dart:convert';

import 'package:bb_mobile/core/storage/sqlite_datasource.dart';
import 'package:bb_mobile/core/transaction/data/electrum_service.dart';
import 'package:bb_mobile/core/transaction/data/models/transaction_mapper.dart';
import 'package:bb_mobile/core/transaction/domain/entities/tx.dart';
import 'package:bb_mobile/locator.dart';

class TransactionRepository {
  final _electrum = ElectrumService(host: 'blockstream.info', port: 700);

  TransactionRepository();

  Future<Tx> fetch({required String txid}) async {
    final sqlite = locator<SqliteDatasource>();
    final cachedTransaction = await sqlite.managers.transactions
        .filter((e) => e.txid(txid))
        .getSingleOrNull();

    if (cachedTransaction != null) {
      return TransactionMapper.fromSqlite(cachedTransaction);
    }

    // If not found in cache, fetch from Electrum
    final txBytes = await _electrum.getTransaction(txid);
    final tx = await TransactionMapper.fromBytes(txBytes);

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
