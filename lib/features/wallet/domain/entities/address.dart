import 'package:freezed_annotation/freezed_annotation.dart';

part 'address.freezed.dart';

enum AddressKind {
  deposit,
  change,
  external,
}

enum AddressStatus {
  unused,
  active,
  used,
  copied,
}

@freezed
sealed class Address with _$Address {
  const Address._();

  factory Address.bitcoin({
    required String address,
    int? index,
    required AddressKind kind,
    required AddressStatus state,
    String? label,
    String? spentTxId,
    @Default(true) bool spendable,
    @Default(0) int highestPreviousBalance,
    @Default(0) int balance,
  }) = BitcoinAddress;

  factory Address.liquid({
    required String address, // Confidential address
    String? standard, // Regular address
    int? index,
    required AddressKind kind,
    required AddressStatus state,
    String? label,
    String? spentTxId,
    @Default(true) bool spendable,
    @Default(0) int highestPreviousBalance,
    @Default(0) int balance,
  }) = LiquidAddress;
}
