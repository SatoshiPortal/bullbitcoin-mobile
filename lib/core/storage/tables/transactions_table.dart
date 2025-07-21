import 'dart:convert';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/transaction/domain/entities/tx.dart';
import 'package:bb_mobile/core/transaction/domain/entities/tx_vin.dart';
import 'package:bb_mobile/core/transaction/domain/entities/tx_vout.dart';
import 'package:drift/drift.dart';

@DataClassName('TransactionModel')
class Transactions extends Table {
  TextColumn get txid => text()();

  IntColumn get version => integer()();
  TextColumn get size => text()();
  TextColumn get vsize => text()();
  IntColumn get locktime => integer()();

  TextColumn get vin => text()();
  TextColumn get vout => text()();

  TextColumn? get blockhash => text().nullable()();
  IntColumn? get height => integer().nullable()();
  IntColumn? get confirmations => integer().nullable()();
  IntColumn? get time => integer().nullable()();
  IntColumn? get blocktime => integer().nullable()();

  @override
  Set<Column> get primaryKey => {txid};
}

extension TransactionModelExtension on TransactionModel {
  static RawBitcoinTxEntity toEntity(TransactionModel row) {
    return RawBitcoinTxEntity(
      txid: row.txid,
      version: row.version,
      size: BigInt.parse(row.size),
      vsize: BigInt.parse(row.vsize),
      locktime: row.locktime,
      vin:
          (json.decode(row.vin) as List)
              .map((e) => TxVin.fromJson(e as Map<String, dynamic>))
              .toList(),
      vout:
          (json.decode(row.vout) as List)
              .map((e) => TxVout.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}
