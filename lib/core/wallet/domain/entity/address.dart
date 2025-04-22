import 'package:bb_mobile/core/labels/data/labelable.dart';
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
sealed class Address with _$Address implements Labelable {
  const Address._();

  factory Address.bitcoin({
    required int index,
    required String address,
    //String? label,
    required AddressKeyChain keyChain,
    required AddressStatus status,
    // String? txId, TODO: analyze if it is not better to add a GetTransactionFromAddress function in the TransactionRepository and get the txId from there in a use case
    int? highestPreviousBalanceSat,
    int? balanceSat,
    required String walletId,
  }) = BitcoinAddress;

  factory Address.liquid({
    required int index,
    required String standard, // Standard address
    required String confidential, // Confidential address
    //String? label,
    required AddressKeyChain keyChain,
    required AddressStatus status,
    //String? txId,
    int? highestPreviousBalanceSat,
    int? balanceSat,
    required String walletId,
  }) = LiquidAddress;

  // TODO: Validate if the standard or confidential address should be used
  String get address => when(
      bitcoin: (index, address, _, __, ___, ____, _____) => address,
      liquid: (index, standard, confidential, __, ___, ____, _____, ______) =>
          confidential);

  String get standardAddress => when(
      bitcoin: (index, address, __, ___, ____, _____, ______) => address,
      liquid: (index, standard, confidential, __, ___, ____, _____, ______) =>
          standard);

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

  @override
  String toRef() => address;
}
