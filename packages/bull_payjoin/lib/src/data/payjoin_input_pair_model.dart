import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'payjoin_input_pair_model.freezed.dart';

@freezed
abstract class PayjoinInputPairModel with _$PayjoinInputPairModel {
  const factory PayjoinInputPairModel({
    required String txId,
    required int vout,
    @Default([]) List<int> scriptSigRawOutputScript,
    @Default(0xFFFFFFFF) int sequence,
    @Default([]) List<Uint8List> witness,
    BigInt? value,
    required Uint8List scriptPubkey,
    @Default([]) List<int> redeemScriptRawOutputScript,
    @Default([]) List<int> witnessScriptRawOutputScript,
  }) = _PayjoinInputPairModel;
  const PayjoinInputPairModel._();
}
