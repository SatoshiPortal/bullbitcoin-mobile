import 'package:bb_mobile/core/transaction/domain/entities/tx_script_sig.dart';
import 'package:bb_mobile/core/transaction/domain/entities/tx_vin.dart';
import 'package:bb_mobile/core/transaction/domain/entities/tx_vout.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'tx.freezed.dart';

@freezed
abstract class RawBitcoinTxEntity with _$RawBitcoinTxEntity {
  const factory RawBitcoinTxEntity({
    required String txid,
    required int version,
    required BigInt size,
    required BigInt vsize,
    required int locktime,
    required List<TxVin> vin,
    required List<TxVout> vout,
  }) = _RawBitcoinTxEntity;

  const RawBitcoinTxEntity._();

  static Future<RawBitcoinTxEntity> fromBytes(List<int> bytes) async {
    final bdkTx = await bdk.Transaction.fromBytes(transactionBytes: bytes);

    final txid = bdkTx.txid();
    final version = bdkTx.version();
    final vsize = bdkTx.vsize();
    final size = bdkTx.size();
    final locktime = bdkTx.lockTime().field0;
    final inputs = bdkTx.input();
    final outputs = bdkTx.output();

    final vout = <TxVout>[];
    for (var i = 0; i < outputs.length; i++) {
      final output = outputs[i];
      vout.add(_mapOutput(output, i));
    }

    return RawBitcoinTxEntity(
      txid: txid,
      version: version,
      size: size,
      vsize: vsize,
      locktime: locktime,
      vin: inputs.map(_mapInput).toList(),
      vout: vout,
    );
  }

  static Future<RawBitcoinTxEntity> fromPsbt(String psbtBase64) async {
    final psbt = await bdk.PartiallySignedTransaction.fromString(psbtBase64);
    final txBytes = psbt.extractTx().serialize();
    return fromBytes(txBytes);
  }

  static TxVin _mapInput(bdk.TxIn input) {
    return TxVin(
      txid: input.previousOutput.txid,
      vout: input.previousOutput.vout,
      sequence: input.sequence,
      scriptSig:
          input.scriptSig != null
              ? TxScriptSig(bytes: input.scriptSig!.bytes)
              : null,
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
