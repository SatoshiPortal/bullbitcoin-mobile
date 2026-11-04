import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_input_details.freezed.dart';

@freezed
sealed class TransactionInputDetails with _$TransactionInputDetails {
  const factory TransactionInputDetails.bitcoin({
    required String txId,
    required int vin,
    required bool isOwn,
    BigInt? value,
    Uint8List? scriptSig,
    required String previousTxId,
    required int previousTxVout,
  }) = BitcoinTransactionInputDetails;
  const factory TransactionInputDetails.liquid({
    required String txId,
    required int vin,
    required bool isOwn,
    required BigInt value,
    required String scriptPubkey,
    required String previousTxId,
    required int previousTxVout,
  }) = LiquidTransactionInputDetails;
  const TransactionInputDetails._();

  String get labelRef => '$txId:$vin';
}
