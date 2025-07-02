import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_address_model.freezed.dart';

@freezed
sealed class WalletAddressModel with _$WalletAddressModel {
  const factory WalletAddressModel({
    required String walletId,
    required int index,
    required String address,
    @Default(false) bool isChange,
    @Default(0) int balanceSat,
    @Default(0) int nrOfTransactions,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _WalletAddressModel;
  const WalletAddressModel._();

  String get labelRef => address;
}
