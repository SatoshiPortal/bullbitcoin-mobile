import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_output_model.freezed.dart';

@freezed
sealed class TransactionOutputModel with _$TransactionOutputModel {
  /// [isChange] tells our own change apart from what we paid out — the only
  /// way to find the recipient in a send-to-self, where we own every output.
  /// From the bdk keychain: internal is change, external is a destination.
  const factory TransactionOutputModel.bitcoin({
    required String txId,
    required int vout,
    required bool isOwn,
    BigInt? value,
    required Uint8List scriptPubkey,
    String? address,
    @Default(false) bool isChange,
  }) = BitcoinTransactionOutputModel;

  /// [isChange] is always false: lwk exposes no internal keychain, so change
  /// cannot be identified.
  const factory TransactionOutputModel.liquid({
    required String txId,
    required int vout,
    required bool isOwn,
    required BigInt value,
    required String scriptPubkey,
    required String address,
    @Default(false) bool isChange,
  }) = LiquidTransactionOutputModel;
  const TransactionOutputModel._();

  String get labelRef => '$txId:$vout';
}
