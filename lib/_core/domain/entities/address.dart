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
    required int index,
    AddressKind? kind,
    AddressStatus? state,
    String? spentTxId,
    bool? spendable,
    BigInt? highestPreviousBalance,
    BigInt? balanceSat,
  }) = BitcoinAddress;

  factory Address.liquid({
    required String standard, // Standard address
    required String confidential, // Confidential address
    required int index,
    AddressKind? kind,
    AddressStatus? state,
    String? spentTxId,
    bool? spendable,
    BigInt? highestPreviousBalanceSat,
    BigInt? balanceSat,
  }) = LiquidAddress;

  // TODO: Validate if the standard or confidential address should be used
  String get address => when(
        bitcoin: (address, _, __, ___, ____, _____, ______, _______) => address,
        liquid: (
          standard,
          confidential,
          __,
          ___,
          ____,
          _____,
          ______,
          _______,
          ________,
        ) =>
            confidential,
      );

  String get standardAddress => when(
        bitcoin: (address, __, ___, ____, _____, ______, _______, ________) =>
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
          ________,
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
