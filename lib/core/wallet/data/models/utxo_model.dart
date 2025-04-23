import 'dart:typed_data';

import 'package:bb_mobile/core/wallet/domain/entity/address.dart';
import 'package:bb_mobile/core/wallet/domain/entity/utxo.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'utxo_model.freezed.dart';

@freezed
sealed class UtxoModel with _$UtxoModel {
  const factory UtxoModel({
    required String txId,
    required int vout,
    BigInt?
        value, // TODO: make non-nullable once separate TxInput/TxOutput entities/models exist
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

  // TODO: move to TxOutput/TxInput model
  String get labelRef => '$txId:$vout';

  Utxo toEntity({
    List<String> labels = const [],
    Address? address,
    bool isFrozen = false,
  }) {
    return Utxo(
      txId: txId,
      vout: vout,
      value: value,
      labels: labels,
      scriptPubkey: scriptPubkey,
      address: address,
      isFrozen: isFrozen,
    );
  }
}
