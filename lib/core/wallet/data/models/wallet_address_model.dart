import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_address_model.freezed.dart';

@freezed
sealed class WalletAddressModel with _$WalletAddressModel {
  const factory WalletAddressModel.bitcoin({
    required int index,
    required String address,
  }) = BitcoinWalletAddressModel;
  const factory WalletAddressModel.liquid({
    required int index,
    required String standard,
    required String confidential,
  }) = LiquidWalletAddressModel;
  const WalletAddressModel._();

  String get address => switch (this) {
    BitcoinWalletAddressModel(:final address) => address,
    LiquidWalletAddressModel(:final confidential) => confidential,
  };
}
