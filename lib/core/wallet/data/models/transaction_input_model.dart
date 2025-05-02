import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_input_model.freezed.dart';

@freezed
sealed class TransactionInputModel with _$TransactionInputModel {
  const factory TransactionInputModel({
    required String txId,
    required int vin,
    BigInt? value,
    Uint8List? scriptSig,
    required String previousTxId,
    required int previousTxVout,
  }) = _TransactionInputModel;
  const TransactionInputModel._();

  String get labelRef => '$txId:$vin';
}
