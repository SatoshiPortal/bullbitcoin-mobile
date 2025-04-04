import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'utxo_model.freezed.dart';

@freezed
sealed class UtxoModel with _$UtxoModel {
  const factory UtxoModel({
    required String txId,
    required int vout,
    required BigInt value,
    required Uint8List scriptPubkey,
  }) = _UtxoModel;
  const UtxoModel._();
}
