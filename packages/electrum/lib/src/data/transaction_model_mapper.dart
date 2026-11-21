import 'dart:convert';

import 'package:electrum/src/storage/transactions_table.drift.dart'
    show TransactionModel;
import 'package:sync/sync.dart' show BitcoinTx, TxVin, TxVout;

/// Maps the generated Electrum cache row into the app's transaction entity
/// without importing the composing database to reach the row type.
extension TransactionModelExtension on TransactionModel {
  static BitcoinTx toEntity(TransactionModel row) {
    return BitcoinTx(
      txid: row.txid,
      version: row.version,
      size: BigInt.parse(row.size),
      vsize: BigInt.parse(row.vsize),
      locktime: row.locktime,
      vin: (json.decode(row.vin) as List)
          .map((e) => TxVin.fromJson(e as Map<String, dynamic>))
          .toList(),
      vout: (json.decode(row.vout) as List)
          .map((e) => TxVout.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
