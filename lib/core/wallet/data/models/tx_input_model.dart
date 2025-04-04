import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'tx_input_model.freezed.dart';

@freezed
sealed class TxInputModel with _$TxInputModel {
  const factory TxInputModel({
    required String txId,
    required int vout,
    required Uint8List scriptPubkey,
  }) = _TxInputModel;
  const TxInputModel._();
}
