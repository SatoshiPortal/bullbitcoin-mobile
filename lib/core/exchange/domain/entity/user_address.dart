import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_address.freezed.dart';
part 'user_address.g.dart';

/// Entity representing a user's physical address.
@freezed
sealed class UserAddress with _$UserAddress {
  const factory UserAddress({
    required String street1,
    String? street2,
    required String city,
    String? province,
    required String postalCode,
    required String countryCode,
  }) = _UserAddress;

  const UserAddress._();

  factory UserAddress.fromJson(Map<String, dynamic> json) =>
      _$UserAddressFromJson(json);

  /// Returns the address as a single formatted string.
  String get addressStringified {
    final parts = <String>[
      street1,
      if (street2 != null && street2!.isNotEmpty) street2!,
      city,
      if (province != null && province!.isNotEmpty) province!,
      postalCode,
      countryCode,
    ];
    return parts.join(', ');
  }
}
