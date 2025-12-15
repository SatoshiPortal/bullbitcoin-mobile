import 'package:freezed_annotation/freezed_annotation.dart';

part 'tx_script_sig.freezed.dart';
part 'tx_script_sig.g.dart';

@freezed
abstract class TxScriptSig with _$TxScriptSig {
  const factory TxScriptSig({required List<int> bytes}) = _TxScriptSig;

  factory TxScriptSig.fromJson(Map<String, dynamic> json) =>
      _$TxScriptSigFromJson(json);
}
