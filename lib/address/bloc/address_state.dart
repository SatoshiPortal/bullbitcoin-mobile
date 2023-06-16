import 'package:bb_mobile/_model/address.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'address_state.freezed.dart';

@freezed
class AddressState with _$AddressState {
  const factory AddressState({
    @Default(false) bool savingAddressName,
    @Default('') String errSavingAddressName,
    @Default(false) bool savedAddressName,
    @Default(false) bool freezingAddress,
    @Default('') String errFreezingAddress,
    @Default(false) bool frozenAddress,
    Address? address,
  }) = _AddressState;
}
