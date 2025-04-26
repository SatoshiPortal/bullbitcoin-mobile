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

  String get address => when(
        bitcoin: (int index, String address) => address,
        liquid: (int index, String standard, String confidential) =>
            confidential,
      );

  String get labelRef => address;
}
