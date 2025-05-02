import 'dart:typed_data';

import 'package:bb_mobile/core/labels/domain/labelable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_input.freezed.dart';

@freezed
sealed class TransactionInput with _$TransactionInput implements Labelable {
  const factory TransactionInput({
    required String txId,
    required int vin,
    BigInt? value,
    Uint8List? scriptSig,
    required String previousTxId,
    required int previousTxVout,
    @Default([]) List<String> labels,
  }) = _TransactionInput;
  const TransactionInput._();

  @override
  String get labelRef => '$txId:$vin';
}
