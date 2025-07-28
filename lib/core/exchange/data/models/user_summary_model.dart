import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_summary_model.freezed.dart';
part 'user_summary_model.g.dart';

@freezed
sealed class UserSummaryModel with _$UserSummaryModel {
  const factory UserSummaryModel({
    required int userNumber,
    required List<String> groups,
    required UserProfileModel profile,
    required String email,
    required List<UserBalanceModel> balances,
    String? language,
    String? currency,
    required UserDcaModel dca,
    required UserAutoBuyModel autoBuy,
  }) = _UserSummaryModel;

  factory UserSummaryModel.fromJson(Map<String, dynamic> json) =>
      _$UserSummaryModelFromJson(json);

  const UserSummaryModel._();

  UserSummary toEntity() {
    return UserSummary(
      userNumber: userNumber,
      groups: groups,
      profile: profile.toEntity(),
      email: email,
      balances: balances.map((b) => b.toEntity()).toList(),
      language: language,
      currency: currency,
      dca: dca.toEntity(),
      autoBuy: autoBuy.toEntity(),
    );
  }
}

@freezed
sealed class UserProfileModel with _$UserProfileModel {
  const factory UserProfileModel({
    required String firstName,
    required String lastName,
  }) = _UserProfileModel;

  factory UserProfileModel.fromJson(Map<String, dynamic> json) =>
      _$UserProfileModelFromJson(json);

  const UserProfileModel._();

  UserProfile toEntity() {
    return UserProfile(firstName: firstName, lastName: lastName);
  }
}

@freezed
sealed class UserBalanceModel with _$UserBalanceModel {
  const factory UserBalanceModel({
    required double amount,
    required String currencyCode,
  }) = _UserBalanceModel;

  factory UserBalanceModel.fromJson(Map<String, dynamic> json) =>
      _$UserBalanceModelFromJson(json);

  const UserBalanceModel._();

  UserBalance toEntity() {
    return UserBalance(amount: amount, currencyCode: currencyCode);
  }
}

@freezed
sealed class UserDcaModel with _$UserDcaModel {
  const factory UserDcaModel({
    required bool isActive,
    String? frequency,
    double? amount,
    String? address,
  }) = _UserDcaModel;

  factory UserDcaModel.fromJson(Map<String, dynamic> json) =>
      _$UserDcaModelFromJson(json);

  const UserDcaModel._();

  UserDca toEntity() {
    return UserDca(
      isActive: isActive,
      frequency: frequency,
      amount: amount,
      address: address,
    );
  }
}

@freezed
sealed class UserAutoBuyAddressesModel with _$UserAutoBuyAddressesModel {
  const factory UserAutoBuyAddressesModel({
    String? bitcoin,
    String? lightning,
    String? liquid,
  }) = _UserAutoBuyAddressesModel;

  factory UserAutoBuyAddressesModel.fromJson(Map<String, dynamic> json) =>
      _$UserAutoBuyAddressesModelFromJson(json);

  const UserAutoBuyAddressesModel._();

  UserAutoBuyAddresses toEntity() {
    return UserAutoBuyAddresses(
      bitcoin: bitcoin,
      lightning: lightning,
      liquid: liquid,
    );
  }
}

@freezed
sealed class UserAutoBuyModel with _$UserAutoBuyModel {
  const factory UserAutoBuyModel({
    required bool isActive,
    required UserAutoBuyAddressesModel addresses,
  }) = _UserAutoBuyModel;

  factory UserAutoBuyModel.fromJson(Map<String, dynamic> json) =>
      _$UserAutoBuyModelFromJson(json);

  const UserAutoBuyModel._();

  UserAutoBuy toEntity() {
    return UserAutoBuy(isActive: isActive, addresses: addresses.toEntity());
  }
}
