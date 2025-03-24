import 'dart:convert';

import 'package:bb_mobile/_core/domain/entities/tx_input.dart';
import 'package:bb_mobile/_core/domain/entities/tx_output.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction.freezed.dart';

@freezed
class Transaction with _$Transaction {
  const factory Transaction({required List<int> bytes}) = _Transaction;

  static Future<Transaction> fromPsbt({required String psbtBase64}) async {
    final psbt = await bdk.PartiallySignedTransaction.fromString(psbtBase64);
    final txBytes = await psbt.extractTx().serialize();
    return Transaction(bytes: txBytes);
  }

  const Transaction._();

  Future<String> get id async {
    final tx = await bdk.Transaction.fromBytes(transactionBytes: bytes);
    return await tx.txid();
  }

  Future<int> get version async {
    final tx = await bdk.Transaction.fromBytes(transactionBytes: bytes);
    return await tx.version();
  }

  Future<int> get locktime async {
    final tx = await bdk.Transaction.fromBytes(transactionBytes: bytes);
    final locktime = await tx.lockTime();
    return locktime.field0;
  }

  Future<List<TxInput>> get inputs async {
    final tx = await bdk.Transaction.fromBytes(transactionBytes: bytes);
    final txInList = await tx.input();
    final inputs = txInList
        .map(
          (e) => TxInput(
            txId: e.previousOutput.txid,
            vout: e.previousOutput.vout,
            scriptPubkey: e.scriptSig.bytes,
          ),
        )
        .toList();
    return inputs;
  }

  Future<List<TxOutput>> get outputs async {
    final tx = await bdk.Transaction.fromBytes(transactionBytes: bytes);
    final txOutList = await tx.output();
    final outputs = txOutList
        .map((e) => TxOutput(value: e.value, script: e.scriptPubkey.bytes))
        .toList();
    return outputs;
  }

  String toBase64() => base64Encode(bytes);
}
