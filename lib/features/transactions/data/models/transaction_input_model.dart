import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_input_model.freezed.dart';

@freezed
sealed class TransactionInputModel with _$TransactionInputModel {
  const factory TransactionInputModel.bitcoin({
    required String txId,
    required int vin,
    required bool isOwn,
    BigInt? value,
    Uint8List? scriptSig,
    required String previousTxId,
    required int previousTxVout,
  }) = BitcoinTransactionInputModel;
  const factory TransactionInputModel.liquid({
    required String txId,
    required int vin,
    required bool isOwn,
    required BigInt value,
    required String scriptPubkey,
    required String previousTxId,
    required int previousTxVout,
  }) = LiquidTransactionInputModel;
  const TransactionInputModel._();

  String get labelRef => '$txId:$vin';
}
