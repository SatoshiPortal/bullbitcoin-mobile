import 'dart:typed_data';


import 'package:freezed_annotation/freezed_annotation.dart';

part 'tx_input.freezed.dart';

@freezed
sealed class TxInput with _$TxInput {
  const factory TxInput({
    required String txId,
    required int vout,
    required Uint8List scriptPubkey,
  }) = _TxInput;
  const TxInput._();
}
