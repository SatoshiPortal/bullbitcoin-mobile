import 'package:bb_mobile/core_deprecated/transaction/domain/entities/tx_script_sig.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'tx_vout.freezed.dart';
part 'tx_vout.g.dart';

@freezed
abstract class TxVout with _$TxVout {
  const factory TxVout({
    required BigInt value,
    required int n,
    required TxScriptSig scriptPubKey,
  }) = _TxVout;

  factory TxVout.fromJson(Map<String, dynamic> json) => _$TxVoutFromJson(json);
}
