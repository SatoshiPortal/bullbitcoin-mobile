import 'package:bb_mobile/core/labels/domain/labelable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_address.freezed.dart';

enum WalletAddressKeyChain { internal, external }

enum WalletAddressStatus { unused, used }

@freezed
sealed class WalletAddress with _$WalletAddress implements Labelable {
  factory WalletAddress.bitcoin({
    required String walletId,
    required int index,
    required String address,
    @Default(WalletAddressKeyChain.external) WalletAddressKeyChain keyChain,
    @Default(WalletAddressStatus.used) WalletAddressStatus status,
    int? highestPreviousBalanceSat,
    int? balanceSat,
    List<String>? labels,
  }) = BitcoinWalletAddress;

  factory WalletAddress.liquid({
    required String walletId,
    required int index,
    required String standard, // Standard address
    required String confidential, // Confidential address
    @Default(WalletAddressKeyChain.external) WalletAddressKeyChain keyChain,
    @Default(WalletAddressStatus.used) WalletAddressStatus status,
    int? highestPreviousBalanceSat,
    int? balanceSat,
    List<String>? labels,
  }) = LiquidWalletAddress;

  factory WalletAddress.external({required String payload}) = AddressOnly;

  const WalletAddress._();

  String get address => switch (this) {
    BitcoinWalletAddress(:final address) => address,
    LiquidWalletAddress(:final confidential) => confidential,
    AddressOnly(:final payload) => payload,
  };

  String get standardAddress => switch (this) {
    BitcoinWalletAddress(:final address) => address,
    LiquidWalletAddress(:final standard) => standard,
    AddressOnly(:final payload) => payload,
  };

  int get index => switch (this) {
    BitcoinWalletAddress(:final index) => index,
    LiquidWalletAddress(:final index) => index,
    AddressOnly() => 0,
  };

  /// Returns true if this is a Bitcoin address
  bool get isBitcoin => switch (this) {
    BitcoinWalletAddress() => true,
    _ => false,
  };

  /// Returns true if this is a Liquid address
  bool get isLiquid => switch (this) {
    LiquidWalletAddress() => true,
    _ => false,
  };

  @override
  String get labelRef => address;
}
