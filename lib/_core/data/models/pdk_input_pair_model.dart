import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'pdk_input_pair_model.freezed.dart';

@freezed
class PdkInputPairModel with _$PdkInputPairModel {
  const factory PdkInputPairModel(
      {required String txId,
      required int vout,
      @Default([]) List<int> scriptSigRawOutputScript,
      @Default(0xFFFFFFFF) int sequence,
      @Default([]) List<Uint8List> witness,
      required BigInt value,
      required Uint8List scriptPubkey,
      @Default([]) List<int> redeemScriptRawOutputScript,
      @Default([]) List<int> witnessScriptRawOutputScript,
      required}) = _PdkInputPairModel;
  const PdkInputPairModel._();
}
