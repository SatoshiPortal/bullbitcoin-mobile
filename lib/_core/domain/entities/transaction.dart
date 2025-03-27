import 'package:bb_mobile/_core/domain/entities/tx_input.dart';
import 'package:bb_mobile/_core/domain/entities/tx_output.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class Transaction {
  final bdk.PartiallySignedTransaction _psbt;

  const Transaction.fromBdkPsbt(this._psbt);

  static Future<Transaction> fromPsbtBase64(String psbtBase64) async {
    final psbt = await bdk.PartiallySignedTransaction.fromString(psbtBase64);
    return Transaction.fromBdkPsbt(psbt);
  }

  String toPsbtBase64() => _psbt.asString();

  bdk.Transaction get _tx => _psbt.extractTx();

  Future<String> get id async => await _tx.txid();

  Future<int> get version async => await _tx.version();

  Future<int> get locktime async {
    final locktime = await _tx.lockTime();
    return locktime.field0;
  }

  Future<List<TxInput>> get inputs async {
    final txInList = await _tx.input();
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
    final txOutList = await _tx.output();
    final outputs = txOutList
        .map((e) => TxOutput(value: e.value, script: e.scriptPubkey.bytes))
        .toList();
    return outputs;
  }

  BigInt? get feeAmount => _psbt.feeAmount();

  double? get satPerVb => _psbt.feeRate()?.satPerVb;
}
