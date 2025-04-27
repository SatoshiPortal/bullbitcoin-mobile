import 'dart:typed_data';

import 'package:bb_mobile/core/labels/data/labelable.dart';
import 'package:bb_mobile/core/wallet/domain/entity/address.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'utxo.freezed.dart';

@freezed
sealed class Utxo with _$Utxo implements Labelable {
  const factory Utxo({
    required String txId,
    required int vout,
    BigInt?
        value, // TODO: make required once we have separate TxInput entity/model
    required Uint8List scriptPubkey,
    Address?
        address, // TODO: make required once we have separate TxOutput entity/model
    @Default([]) List<String> labels,
    @Default(false) bool isFrozen,
  }) = _Utxo;
  const Utxo._();

  // TODO: move to TxOutput entity/model
  @override
  String toRef() => '$txId:$vout';
}
