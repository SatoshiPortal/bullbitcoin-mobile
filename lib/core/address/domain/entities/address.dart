import 'package:freezed_annotation/freezed_annotation.dart';

part 'address.freezed.dart';

enum AddressKeyChain {
  internal,
  external,
}

enum AddressStatus {
  unused,
  used,
}

@freezed
sealed class Address with _$Address {
  const Address._();

  factory Address.bitcoin({
    required String walletId,
    required String address,
    required int index,
    //String? label,
    required AddressKeyChain keyChain,
    required AddressStatus status,
    // String? txId, TODO: analyze if it is not better to add a GetTransactionFromAddress function in the TransactionRepository and get the txId from there in a use case
    int? highestPreviousBalanceSat,
    int? balanceSat,
  }) = BitcoinAddress;

  factory Address.liquid({
    required String walletId,
    required String standard, // Standard address
    required String confidential, // Confidential address
    required int index,
    //String? label,
    required AddressKeyChain keyChain,
    required AddressStatus status,
    //String? txId,
    int? highestPreviousBalanceSat,
    int? balanceSat,
  }) = LiquidAddress;

  // TODO: Validate if the standard or confidential address should be used
  String get address => when(
        bitcoin: (
          address,
          _,
          __,
          ___,
          ____,
          _____,
          ______,
        ) =>
            address,
        liquid: (
          standard,
          confidential,
          __,
          ___,
          ____,
          _____,
          ______,
          _______,
        ) =>
            confidential,
      );

  String get standardAddress => when(
        bitcoin: (
          address,
          __,
          ___,
          ____,
          _____,
          ______,
          _______,
        ) =>
            address,
        liquid: (
          standard,
          _,
          __,
          ___,
          ____,
          _____,
          ______,
          _______,
        ) =>
            standard,
      );

  /// Returns true if this is a Bitcoin address
  bool get isBitcoin => maybeMap(
        bitcoin: (_) => true,
        orElse: () => false,
      );

  /// Returns true if this is a Liquid address
  bool get isLiquid => maybeMap(
        liquid: (_) => true,
        orElse: () => false,
      );
}
