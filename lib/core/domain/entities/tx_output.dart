import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'tx_output.freezed.dart';

@freezed
sealed class TxOutput with _$TxOutput {
  const factory TxOutput({
    required BigInt value,
    required Uint8List script,
  }) = _TxOutput;
  const TxOutput._();
}
