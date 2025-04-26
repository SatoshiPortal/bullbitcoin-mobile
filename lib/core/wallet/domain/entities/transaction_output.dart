import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_output.freezed.dart';

@freezed
sealed class TransactionOutput with _$TransactionOutput {
  const factory TransactionOutput.bitcoin({
    required String txId,
    required int vout,
    BigInt? value,
    required Uint8List scriptPubkey,
    required String address,
    @Default([]) List<String> labels,
    @Default([]) List<String> addressLabels,
    @Default(false) bool isFrozen,
  }) = BitcoinTransactionOutput;
  const factory TransactionOutput.liquid({
    required String txId,
    required int vout,
    required BigInt value,
    required String scriptPubkey,
    required String standardAddress,
    required String confidentialAddress,
    @Default([]) List<String> labels,
    @Default([]) List<String> addressLabels,
    @Default(false) bool isFrozen,
  }) = LiquidTransactionOutput;
  const TransactionOutput._();

  String get labelRef => '$txId:$vout';
}
