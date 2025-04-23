import 'dart:convert';

import 'package:bb_mobile/core/transaction/data/sqlite_datasource.dart';
import 'package:bb_mobile/core/transaction/domain/entities/tx.dart';
import 'package:bb_mobile/core/transaction/domain/entities/tx_script_sig.dart';
import 'package:bb_mobile/core/transaction/domain/entities/tx_vin.dart';
import 'package:bb_mobile/core/transaction/domain/entities/tx_vout.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class TransactionMapper {
  static Transaction toModel(Tx tx) {
    return Transaction(
      txid: tx.txid,
      version: tx.version,
      size: tx.size.toString(),
      vsize: tx.vsize.toString(),
      locktime: tx.locktime,
      vin: json.encode(tx.vin),
      vout: json.encode(tx.vout),
    );
  }

  static Tx fromSqlite(Transaction row) {
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

  static Future<Tx> fromBytes(List<int> bytes) async {
    final bdkTx = await bdk.Transaction.fromBytes(transactionBytes: bytes);

    final txid = await bdkTx.txid();
    final version = await bdkTx.version();
    final vsize = await bdkTx.vsize();
    final size = await bdkTx.size();
    final locktime = (await bdkTx.lockTime()).field0;
    final inputs = await bdkTx.input();
    final outputs = await bdkTx.output();

    final vout = <TxVout>[];
    for (var i = 0; i < outputs.length; i++) {
      final output = outputs[i];
      vout.add(_mapOutput(output, i));
    }

    return Tx(
      txid: txid,
      version: version,
      size: size,
      vsize: vsize,
      locktime: locktime,
      vin: inputs.map(_mapInput).toList(),
      vout: vout,
    );
  }

  static TxVin _mapInput(bdk.TxIn input) {
    return TxVin(
      txid: input.previousOutput.txid,
      vout: input.previousOutput.vout,
      sequence: input.sequence,
      scriptSig: TxScriptSig(bytes: input.scriptSig.bytes),
    );
  }

  static TxVout _mapOutput(bdk.TxOut output, int index) {
    return TxVout(
      value: output.value,
      n: index, // TODO(azad): bdk does not expose vout index?
      scriptPubKey: TxScriptSig(bytes: output.scriptPubkey.bytes),
    );
  }
}
