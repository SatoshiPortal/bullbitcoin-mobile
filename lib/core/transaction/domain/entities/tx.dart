import 'package:freezed_annotation/freezed_annotation.dart';

part 'tx.freezed.dart';
part 'tx.g.dart';

@freezed
class TxScriptSig with _$TxScriptSig {
  const factory TxScriptSig({required List<int> bytes}) = _TxScriptSig;

  factory TxScriptSig.fromJson(Map<String, dynamic> json) =>
      _$TxScriptSigFromJson(json);
}

@freezed
class TxVin with _$TxVin {
  const factory TxVin({
    String? coinbase,
    int? sequence,
    String? txid,
    int? vout,
    TxScriptSig? scriptSig,
  }) = _TxVin;

  factory TxVin.fromJson(Map<String, dynamic> json) => _$TxVinFromJson(json);
}

@freezed
class TxVout with _$TxVout {
  const factory TxVout({
    required BigInt value,
    required int n,
    required TxScriptSig scriptPubKey,
  }) = _TxVout;

  factory TxVout.fromJson(Map<String, dynamic> json) => _$TxVoutFromJson(json);
}

@freezed
class Tx with _$Tx {
  const factory Tx({
    required String txid,
    required int version,
    required BigInt size,
    required BigInt vsize,
    required int locktime,
    required List<TxVin> vin,
    required List<TxVout> vout,
  }) = _Tx;

  factory Tx.fromJson(Map<String, dynamic> json) => _$TxFromJson(json);
}
