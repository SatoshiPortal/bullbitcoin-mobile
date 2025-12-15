import 'package:bb_mobile/core_deprecated/transaction/domain/entities/tx_script_sig.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'tx_vin.freezed.dart';
part 'tx_vin.g.dart';

@freezed
abstract class TxVin with _$TxVin {
  const factory TxVin({
    String? coinbase,
    int? sequence,
    String? txid,
    int? vout,
    TxScriptSig? scriptSig,
  }) = _TxVin;

  factory TxVin.fromJson(Map<String, dynamic> json) => _$TxVinFromJson(json);
}
