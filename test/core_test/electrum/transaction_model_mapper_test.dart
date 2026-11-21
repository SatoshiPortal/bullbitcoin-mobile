import 'dart:convert';

import 'package:bb_mobile/core/electrum/adapters/transaction_model_mapper.dart';
import 'package:bb_mobile/core/storage/tables/transactions_table.drift.dart'
    show TransactionModel;
import 'package:sync/sync.dart' show TxVin, TxVout, TxScriptSig;
import 'package:flutter_test/flutter_test.dart';

/// The existing Electrum repository mapper is exercised directly because the
/// remote datasource tests stop at socket failures and never reach this code.
void main() {
  const txid =
      '4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b';

  const vin = [
    TxVin(
      sequence: 4294967295,
      txid: '0000000000000000000000000000000000000000000000000000000000000000',
      vout: 4294967295,
      scriptSig: TxScriptSig(bytes: [4, 255, 255, 0, 29, 1, 4]),
    ),
  ];

  final vout = [
    TxVout(
      value: BigInt.from(5000000000),
      n: 0,
      scriptPubKey: const TxScriptSig(bytes: [65, 4, 103, 138]),
    ),
    TxVout(
      value: BigInt.from(150000),
      n: 1,
      scriptPubKey: const TxScriptSig(bytes: [81]),
    ),
  ];

  TransactionModel rowFromWriter() => TransactionModel(
    txid: txid,
    version: 1,
    size: '285',
    vsize: '285',
    locktime: 0,
    vin: json.encode(vin.map((e) => e.toJson()).toList()),
    vout: json.encode(vout.map((e) => e.toJson()).toList()),
  );

  test('toEntity restores the transaction entity from the cached row', () {
    final entity = TransactionModelExtension.toEntity(rowFromWriter());

    expect(entity.txid, txid);
    expect(entity.version, 1);
    expect(entity.size, BigInt.from(285));
    expect(entity.vsize, BigInt.from(285));
    expect(entity.locktime, 0);
  });

  test('toEntity decodes every input back into TxVin', () {
    final entity = TransactionModelExtension.toEntity(rowFromWriter());

    expect(entity.vin, hasLength(vin.length));
    expect(entity.vin.single.sequence, vin.single.sequence);
    expect(entity.vin.single.txid, vin.single.txid);
    expect(entity.vin.single.vout, vin.single.vout);
    expect(entity.vin.single.scriptSig?.bytes, vin.single.scriptSig?.bytes);
  });

  test('toEntity decodes every output back into TxVout, values included', () {
    final entity = TransactionModelExtension.toEntity(rowFromWriter());

    expect(entity.vout, hasLength(vout.length));
    for (final (index, output) in entity.vout.indexed) {
      expect(output.value, vout[index].value);
      expect(output.n, vout[index].n);
      expect(output.scriptPubKey.bytes, vout[index].scriptPubKey.bytes);
    }
  });

  test('toEntity ignores the nullable confirmation columns', () {
    final row = TransactionModel(
      txid: txid,
      version: 2,
      size: '10',
      vsize: '10',
      locktime: 5,
      vin: json.encode(const <TxVin>[].map((e) => e.toJson()).toList()),
      vout: json.encode(const <TxVout>[].map((e) => e.toJson()).toList()),
      blockhash: '00ff',
      height: 800000,
      confirmations: 6,
      time: 1700000000,
      blocktime: 1700000000,
    );

    final entity = TransactionModelExtension.toEntity(row);

    expect(entity.locktime, 5);
    expect(entity.vin, isEmpty);
    expect(entity.vout, isEmpty);
  });
}
