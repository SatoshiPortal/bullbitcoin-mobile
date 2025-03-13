import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'utxo.freezed.dart';

@freezed
sealed class Utxo with _$Utxo {
  const factory Utxo({
    required String txId,
    required int vout,
    required BigInt value,
    required Uint8List scriptPubkey,
  }) = _Utxo;
  const Utxo._();
}
