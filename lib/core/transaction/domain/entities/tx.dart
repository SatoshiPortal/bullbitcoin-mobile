import 'package:bb_mobile/core/transaction/domain/entities/tx_vin.dart';
import 'package:bb_mobile/core/transaction/domain/entities/tx_vout.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'tx.freezed.dart';
part 'tx.g.dart';

@freezed
abstract class Tx with _$Tx {
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
