import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_address.freezed.dart';

enum WalletAddressKeyChain {
  internal,
  external,
}

enum WalletAddressStatus {
  unused,
  used,
}

@freezed
sealed class WalletAddress with _$WalletAddress {
  factory WalletAddress.bitcoin({
    required int index,
    required String address,
    @Default(WalletAddressKeyChain.external) WalletAddressKeyChain keyChain,
    @Default(WalletAddressStatus.used) WalletAddressStatus status,
    int? highestPreviousBalanceSat,
    int? balanceSat,
    List<String>? labels,
  }) = BitcoinWalletAddress;

  factory WalletAddress.liquid({
    required int index,
    required String standard, // Standard address
    required String confidential, // Confidential address
    @Default(WalletAddressKeyChain.external) WalletAddressKeyChain keyChain,
    @Default(WalletAddressStatus.used) WalletAddressStatus status,
    int? highestPreviousBalanceSat,
    int? balanceSat,
    List<String>? labels,
  }) = LiquidWalletAddress;

  const WalletAddress._();

  String get address => when(
        bitcoin: (
          int? index,
          String address,
          WalletAddressKeyChain keyChain,
          WalletAddressStatus status,
          int? highestPreviousBalanceSat,
          int? balanceSat,
          List<String>? labels,
        ) =>
            address,
        liquid: (
          int? index,
          String standard,
          String confidential,
          WalletAddressKeyChain keyChain,
          WalletAddressStatus status,
          int? highestPreviousBalanceSat,
          int? balanceSat,
          List<String>? labels,
        ) =>
            confidential,
      );

  String get standardAddress => when(
        bitcoin: (
          int? index,
          String address,
          WalletAddressKeyChain keyChain,
          WalletAddressStatus status,
          int? highestPreviousBalanceSat,
          int? balanceSat,
          List<String>? labels,
        ) =>
            address,
        liquid: (
          int? index,
          String standard,
          String confidential,
          WalletAddressKeyChain keyChain,
          WalletAddressStatus status,
          int? highestPreviousBalanceSat,
          int? balanceSat,
          List<String>? labels,
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

  String get labelRef => address;
}
