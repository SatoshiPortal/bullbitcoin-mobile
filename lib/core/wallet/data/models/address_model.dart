import 'package:bb_mobile/core/wallet/domain/entity/address.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'address_model.freezed.dart';

@freezed
sealed class AddressModel with _$AddressModel {
  const factory AddressModel.bitcoin({
    required int index,
    required String address,
  }) = BitcoinAddressModel;
  const factory AddressModel.liquid({
    required int index,
    required String standard,
    required String confidential,
  }) = LiquidAddressModel;
  const AddressModel._();

  String get address => when(
        bitcoin: (index, address) => address,
        liquid: (index, standard, confidential) => confidential,
      );

  Address toEntity({
    required String walletId,
    required AddressKeyChain keyChain,
    required AddressStatus status,
    int? balanceSat,
    int? highestPreviousBalanceSat,
  }) {
    return when(
      bitcoin: (index, address) => Address.bitcoin(
        walletId: walletId,
        index: index,
        address: address,
        keyChain: keyChain,
        status: status,
        balanceSat: balanceSat,
        highestPreviousBalanceSat: highestPreviousBalanceSat,
      ),
      liquid: (index, standard, confidential) => Address.liquid(
        walletId: walletId,
        index: index,
        standard: standard,
        confidential: confidential,
        keyChain: keyChain,
        status: status,
        balanceSat: balanceSat,
        highestPreviousBalanceSat: highestPreviousBalanceSat,
      ),
    );
  }
}
