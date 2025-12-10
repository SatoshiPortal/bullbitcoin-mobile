import 'dart:typed_data';

import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bitcoin_tx.freezed.dart';
part 'bitcoin_tx.g.dart';

class BitcoinTx {
  final String txid;
  final int version;
  final BigInt size;
  final BigInt vsize;
  final int locktime;
  final List<TxVin> vin;
  final List<TxVout> vout;

  List<TxVin> get inputs => vin;
  List<TxVout> get outputs => vout;

  const BitcoinTx({
    required this.txid,
    required this.version,
    required this.size,
    required this.vsize,
    required this.locktime,
    required this.vin,
    required this.vout,
  });

  static Future<BitcoinTx> fromBytes(List<int> bytes) async {
    final bdkTx = await bdk.Transaction.fromBytes(transactionBytes: bytes);

    final txid = bdkTx.txid();
    final version = bdkTx.version();
    final vsize = bdkTx.vsize();
    final size = bdkTx.size();
    final locktime = bdkTx.lockTime().field0;
    final inputs = bdkTx.input();
    final outputs = bdkTx.output();

    // ! iterate instead of mapto preserve index order
    final vout = <TxVout>[];
    for (var i = 0; i < outputs.length; i++) {
      final output = outputs[i];
      vout.add(_mapOutput(output, i));
    }

    return BitcoinTx(
      txid: txid,
      version: version,
      size: size,
      vsize: vsize,
      locktime: locktime,
      vin: inputs.map(_mapInput).toList(),
      vout: vout,
    );
  }

  static Future<BitcoinTx> fromPsbt(String psbtBase64) async {
    final psbt = await bdk.PartiallySignedTransaction.fromString(psbtBase64);
    final txBytes = psbt.extractTx().serialize();
    return fromBytes(txBytes);
  }

  static TxVin _mapInput(bdk.TxIn input) {
    return TxVin(
      txid: input.previousOutput.txid,
      vout: input.previousOutput.vout,
      sequence: input.sequence,
      scriptSig: input.scriptSig != null
          ? TxScriptSig(bytes: input.scriptSig!.bytes)
          : null,
    );
  }

  static TxVout _mapOutput(bdk.TxOut output, int index) {
    return TxVout(
      value: output.value,
      n: index,
      scriptPubKey: TxScriptSig(bytes: output.scriptPubkey.bytes),
    );
  }

  Future<int> getAmountReceived({
    required bool isTestnet,
    required String address,
  }) async {
    int totalAmount = 0;
    for (final output in vout) {
      final scriptPubkey = output.scriptPubKey;
      final outputAddress = await bdk.Address.fromScript(
        script: bdk.ScriptBuf(bytes: Uint8List.fromList(scriptPubkey.bytes)),
        network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
      );
      if (outputAddress.asString() == address) {
        totalAmount += output.value.toInt();
      }
    }

    return totalAmount;
  }
}

@freezed
sealed class TxVin with _$TxVin {
  const factory TxVin({
    required int sequence,
    required String txid,
    required int vout,
    required TxScriptSig? scriptSig,
  }) = _TxVin;

  factory TxVin.fromJson(Map<String, dynamic> json) => _$TxVinFromJson(json);
}

@freezed
sealed class TxVout with _$TxVout {
  const factory TxVout({
    required BigInt value,
    required int n,
    required TxScriptSig scriptPubKey,
  }) = _TxVout;

  factory TxVout.fromJson(Map<String, dynamic> json) => _$TxVoutFromJson(json);
}

@freezed
abstract class TxScriptSig with _$TxScriptSig {
  const factory TxScriptSig({required List<int> bytes}) = _TxScriptSig;

  factory TxScriptSig.fromJson(Map<String, dynamic> json) =>
      _$TxScriptSigFromJson(json);
}
