import 'dart:typed_data';

import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_output.freezed.dart';

@freezed
sealed class TransactionOutput with _$TransactionOutput {
  const factory TransactionOutput.bitcoin({
    required String txId,
    required int vout,
    required bool isOwn,
    BigInt? value,
    required Uint8List scriptPubkey,
    String? address,
    @Default([]) List<Label> labels,
    @Default([]) List<Label> addressLabels,
  }) = BitcoinTransactionOutput;

  const factory TransactionOutput.liquid({
    required String txId,
    required int vout,
    required bool isOwn,
    required BigInt value,
    required String scriptPubkey,
    required String address,
    @Default([]) List<Label> labels,
    @Default([]) List<Label> addressLabels,
  }) = LiquidTransactionOutput;

  const TransactionOutput._();
}
