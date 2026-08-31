import 'dart:typed_data';

import 'package:bull_sdk/bdk.dart' as bdk;

final class BitcoinTx {
  final String txid;
  final List<TxInput> inputs;
  final List<TxOutput> outputs;

  const BitcoinTx({
    required this.txid,
    required this.inputs,
    required this.outputs,
  });

  static Future<BitcoinTx> fromBytes(List<int> bytes) async {
    final transaction = bdk.Transaction(
      transactionBytes: Uint8List.fromList(bytes),
    );
    return BitcoinTx(
      txid: transaction.computeTxid().toString(),
      inputs: transaction.input().map((input) {
        return TxInput(
          txid: input.previousOutput.txid.toString(),
          vout: input.previousOutput.vout,
        );
      }).toList(),
      outputs: transaction.output().map((output) {
        return TxOutput(
          value: output.value.toSat(),
          scriptPubkey: output.scriptPubkey.toBytes(),
        );
      }).toList(),
    );
  }

  static Future<BitcoinTx> fromPsbt(String psbtBase64) {
    final psbt = bdk.Psbt(psbtBase64: psbtBase64);
    return fromBytes(psbt.extractTx().serialize());
  }

  Future<int> getAmountReceived({
    required bool isTestnet,
    required String address,
  }) async {
    var total = 0;
    for (final output in outputs) {
      final outputAddress = bdk.Address.fromScript(
        script: bdk.Script(rawOutputScript: output.scriptPubkey),
        network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
      );
      if (outputAddress.toString() == address) total += output.value;
    }
    return total;
  }
}

final class TxInput {
  final String txid;
  final int vout;

  const TxInput({required this.txid, required this.vout});
}

final class TxOutput {
  final int value;
  final Uint8List scriptPubkey;

  const TxOutput({required this.value, required this.scriptPubkey});
}
