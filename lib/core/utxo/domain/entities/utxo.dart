import 'dart:typed_data';

import 'package:bb_mobile/core/labels/data/labelable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'utxo.freezed.dart';

@freezed
sealed class Utxo with _$Utxo implements Labelable {
  const factory Utxo({
    required String txId,
    required int vout,
    BigInt? value,
    required Uint8List scriptPubkey,
    @Default(false) bool isFrozen,
  }) = _Utxo;
  const Utxo._();

  @override
  String toRef() => '$txId:$vout';
}
