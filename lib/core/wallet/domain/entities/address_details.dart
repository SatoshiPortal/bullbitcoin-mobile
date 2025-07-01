import 'package:freezed_annotation/freezed_annotation.dart';

part 'address_details.freezed.dart';

@freezed
sealed class AddressDetails with _$AddressDetails {
  const factory AddressDetails({
    required String address,
    required String walletId,
    required int index,
    @Default(false) bool isChange,
    @Default(0) int balanceSat,
    @Default(0) int nrOfTransactions,
  }) = _AddressDetails;

  const AddressDetails._();

  bool get isUsed => nrOfTransactions > 0;
}
