import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_input.freezed.dart';

@freezed
sealed class TransactionInput with _$TransactionInput {
  const factory TransactionInput({
    required String txId,
    required int vin,
    BigInt? value,
    required Uint8List scriptSig,
    required String previousTxId,
    required int previousTxVout,
    @Default([]) List<String> labels,
  }) = _TransactionInput;
  const TransactionInput._();

  String get labelRef => '$txId:$vin';
}
