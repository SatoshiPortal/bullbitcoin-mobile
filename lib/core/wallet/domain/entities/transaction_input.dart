import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_input.freezed.dart';

@freezed
sealed class TransactionInput with _$TransactionInput {
  const factory TransactionInput.bitcoin({
    required String txId,
    required int vin,
    required bool isOwn,
    BigInt? value,
    Uint8List? scriptSig,
    required String previousTxId,
    required int previousTxVout,
    @Default([]) List<String> labels,
  }) = BitcoinTransactionInput;
  const factory TransactionInput.liquid({
    required String txId,
    required int vin,
    required bool isOwn,
    required BigInt value,
    required String scriptPubkey,
    required String previousTxId,
    required int previousTxVout,
    @Default([]) List<String> labels,
  }) = LiquidTransactionInput;
  const TransactionInput._();
}
