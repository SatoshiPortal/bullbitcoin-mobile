import 'dart:typed_data';

import 'package:bb_mobile/core/utxo/domain/entities/utxo.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'utxo_model.freezed.dart';

@freezed
sealed class UtxoModel with _$UtxoModel {
  const factory UtxoModel({
    required String txId,
    required int vout,
    BigInt? value,
    required Uint8List scriptPubkey,
  }) = _UtxoModel;
  const UtxoModel._();

  factory UtxoModel.fromEntity(Utxo utxo) {
    return UtxoModel(
      txId: utxo.txId,
      vout: utxo.vout,
      value: utxo.value,
      scriptPubkey: utxo.scriptPubkey,
    );
  }

  Utxo toEntity({bool isFrozen = false}) {
    return Utxo(
      txId: txId,
      vout: vout,
      value: value,
      scriptPubkey: scriptPubkey,
      isFrozen: isFrozen,
    );
  }
}
