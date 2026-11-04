import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_output_details.freezed.dart';

@freezed
sealed class TransactionOutputDetails with _$TransactionOutputDetails {
  /// [isChange] tells our own change apart from what we paid out — the only
  /// way to find the recipient in a send-to-self, where we own every output.
  /// From the bdk keychain: internal is change, external is a destination.
  const factory TransactionOutputDetails.bitcoin({
    required String txId,
    required int vout,
    required bool isOwn,
    BigInt? value,
    required Uint8List scriptPubkey,
    String? address,
    @Default(false) bool isChange,
  }) = BitcoinTransactionOutputDetails;

  /// [isChange] is always false: lwk exposes no internal keychain, so change
  /// cannot be identified.
  const factory TransactionOutputDetails.liquid({
    required String txId,
    required int vout,
    required bool isOwn,
    required BigInt value,
    required String scriptPubkey,
    required String address,
    @Default(false) bool isChange,
  }) = LiquidTransactionOutputDetails;
  const TransactionOutputDetails._();

  String get labelRef => '$txId:$vout';
}
