import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'bitcoin_transaction_decoder.dart';

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

  /// Throws [FormatException] when [bytes] are not a transaction.
  static Future<BitcoinTx> fromBytes(List<int> bytes) async =>
      _fromDecoded(decodeBitcoinTransaction(bytes));

  static Future<BitcoinTx> fromPsbt(String psbtBase64) async {
    // BDK extraction needs input metadata to compute fees, so finalized
    // PSBTs stripped of it must fall back to the bitcoin_base path, which
    // does not require that metadata (issue #2654).
    try {
      return _fromDecoded(decodeBitcoinPsbt(psbtBase64));
    } on FormatException {
      // Fall through to bitcoin_base.
    }
    final psbt = Psbt.fromBase64(psbtBase64);
    final txBytes = PsbtBuilder.fromPsbt(psbt).finalizeAll().toBytes();
    return fromBytes(txBytes);
  }

  static BitcoinTx _fromDecoded(DecodedBitcoinTransaction decoded) => BitcoinTx(
    txid: decoded.txid,
    version: decoded.version,
    size: BigInt.from(decoded.size),
    vsize: BigInt.from(decoded.vsize),
    locktime: decoded.locktime,
    vin: [
      for (final input in decoded.inputDetails)
        TxVin(
          txid: input.outpoint.txId,
          vout: input.outpoint.vout,
          sequence: input.sequence,
          scriptSig: TxScriptSig(bytes: input.scriptSig),
        ),
    ],
    vout: [
      for (final (index, output) in decoded.outputs.indexed)
        TxVout(
          value: BigInt.from(output.valueSat),
          n: index,
          scriptPubKey: TxScriptSig(bytes: output.scriptPubkey),
        ),
    ],
  );
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
