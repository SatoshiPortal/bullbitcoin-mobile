import 'package:freezed_annotation/freezed_annotation.dart';

part 'address_model.freezed.dart';

@freezed
class AddressModel with _$AddressModel {
  factory AddressModel({
    required String address,
    int? index,
  }) = _AddressModel;
}
