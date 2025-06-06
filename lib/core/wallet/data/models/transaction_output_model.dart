import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_output_model.freezed.dart';

@freezed
sealed class TransactionOutputModel with _$TransactionOutputModel {
  const factory TransactionOutputModel.bitcoin({
    required String txId,
    required int vout,
    required bool isOwn,
    BigInt? value,
    required Uint8List scriptPubkey,
    String? address,
  }) = BitcoinTransactionOutputModel;
  const factory TransactionOutputModel.liquid({
    required String txId,
    required int vout,
    required bool isOwn,
    required BigInt value,
    required String scriptPubkey,
    required String standardAddress,
    required String confidentialAddress,
  }) = LiquidTransactionOutputModel;
  const TransactionOutputModel._();
}
