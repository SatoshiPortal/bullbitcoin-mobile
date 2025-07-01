import 'package:freezed_annotation/freezed_annotation.dart';

part 'address_details_model.freezed.dart';

@freezed
sealed class AddressDetailsModel with _$AddressDetailsModel {
  const factory AddressDetailsModel({
    required String address,
    required String walletId,
    required int index,
    @Default(false) bool isChange,
    @Default(false) bool isUsed,
    @Default(0) int balanceSat,
    @Default(0) int nrOfTransactions,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _AddressDetailsModel;
  const AddressDetailsModel._();
}
