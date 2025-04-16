import 'dart:convert';

import 'package:bb_mobile/core/transaction/data/drift_datasource.dart';
import 'package:bb_mobile/core/transaction/domain/entities/tx.dart';

import 'package:drift/drift.dart';

class DriftMapper {
  static TransactionsCompanion toDrift(Tx tx) {
    return TransactionsCompanion(
      txid: Value(tx.txid),
      version: Value(tx.version),
      size: Value(tx.size.toString()), // BigInt -> String
      vsize: Value(tx.vsize.toString()),
      locktime: Value(tx.locktime),
      vin: Value(json.encode(tx.vin.map((v) => v.toJson()).toList())),
      vout: Value(json.encode(tx.vout.map((v) => v.toJson()).toList())),
    );
  }

  static Tx? fromDrift(Transaction? row) {
    if (row == null) return null;

    return Tx(
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
