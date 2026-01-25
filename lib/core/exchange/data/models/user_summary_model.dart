import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/value_objects/user_address.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/features/dca/domain/dca.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_summary_model.freezed.dart';
part 'user_summary_model.g.dart';

@freezed
sealed class UserSummaryModel with _$UserSummaryModel {
  const factory UserSummaryModel({
    required int userNumber,
    String? userId,
    required List<String> groups,
    required UserProfileModel profile,
    required String email,
    required List<UserBalanceModel> balances,
    String? language,
    String? currency,
    required UserDcaModel dca,
    required UserAutoBuyModel autoBuy,
    UserAddressModel? address,
    @Default(true) bool emailNotificationsEnabled,
    UserKycDocumentStatusModel? kycDocumentStatus,
  }) = _UserSummaryModel;

  factory UserSummaryModel.fromJson(Map<String, dynamic> json) =>
      _$UserSummaryModelFromJson(json);

  const UserSummaryModel._();

  UserSummary toEntity() {
    return UserSummary(
      userNumber: userNumber,
      userId: userId,
      groups: groups,
      profile: profile.toEntity(),
      email: email,
      balances: balances.map((b) => b.toEntity()).toList(),
      language: language,
      currency: currency,
      dca: dca.toEntity(),
      autoBuy: autoBuy.toEntity(),
      address: address?.toEntity(),
      emailNotificationsEnabled: emailNotificationsEnabled,
      kycDocumentStatus: kycDocumentStatus?.toEntity(),
    );
  }
}

@freezed
sealed class UserAddressModel with _$UserAddressModel {
  const factory UserAddressModel({
    required String street1,
    String? street2,
    required String city,
    String? province,
    required String postalCode,
    required String countryCode,
  }) = _UserAddressModel;

  factory UserAddressModel.fromJson(Map<String, dynamic> json) =>
      _$UserAddressModelFromJson(json);

  const UserAddressModel._();

  UserAddress toEntity() {
    return UserAddress(
      street1: street1,
      street2: street2,
      city: city,
      province: province,
      postalCode: postalCode,
      countryCode: countryCode,
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
    String? recipientType,
    String? currencyCode,
  }) = _UserDcaModel;

  factory UserDcaModel.fromJson(Map<String, dynamic> json) =>
      _$UserDcaModelFromJson(json);

  const UserDcaModel._();

  UserDca toEntity() {
    return UserDca(
      isActive: isActive,
      frequency: switch (frequency?.toLowerCase()) {
        'hourly' => DcaBuyFrequency.hourly,
        'daily' => DcaBuyFrequency.daily,
        'weekly' => DcaBuyFrequency.weekly,
        'monthly' => DcaBuyFrequency.monthly,
        _ => null,
      },
      currency:
          currencyCode != null ? FiatCurrency.fromCode(currencyCode!) : null,
      amount: amount,
      network: switch (recipientType) {
        'OUT_BITCOIN_ADDRESS' => DcaNetwork.bitcoin,
        'OUT_LIGHTNING_ADDRESS' => DcaNetwork.lightning,
        'OUT_LIQUID_ADDRESS' => DcaNetwork.liquid,
        _ => null,
      },
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

/// Model for parsing KYC documents status from API
@freezed
sealed class UserKycDocumentsModel with _$UserKycDocumentsModel {
  const factory UserKycDocumentsModel({
    @Default('NOT_UPLOADED') String id,
    @Default('NOT_UPLOADED') String proofOfResidence,
    @Default('NOT_UPLOADED') String selfie,
  }) = _UserKycDocumentsModel;

  factory UserKycDocumentsModel.fromJson(Map<String, dynamic> json) =>
      _$UserKycDocumentsModelFromJson(json);

  const UserKycDocumentsModel._();

  UserKycDocuments toEntity() {
    return UserKycDocuments(
      id: _parseKycDocumentStatus(id),
      proofOfResidence: _parseKycDocumentStatus(proofOfResidence),
      selfie: _parseKycDocumentStatus(selfie),
    );
  }
}

/// Model for parsing overall KYC document status from API
@freezed
sealed class UserKycDocumentStatusModel with _$UserKycDocumentStatusModel {
  const factory UserKycDocumentStatusModel({
    @Default('NOT_UPLOADED') String secureFileUpload,
    required UserKycDocumentsModel documents,
  }) = _UserKycDocumentStatusModel;

  factory UserKycDocumentStatusModel.fromJson(Map<String, dynamic> json) =>
      _$UserKycDocumentStatusModelFromJson(json);

  const UserKycDocumentStatusModel._();

  UserKycDocumentStatus toEntity() {
    return UserKycDocumentStatus(
      secureFileUpload: _parseKycDocumentStatus(secureFileUpload),
      documents: documents.toEntity(),
    );
  }
}

/// Helper function to parse KYC document status string to enum
KycDocumentStatus _parseKycDocumentStatus(String status) {
  switch (status.toUpperCase()) {
    case 'ACCEPTED':
      return KycDocumentStatus.accepted;
    case 'UNDER_REVIEW':
      return KycDocumentStatus.underReview;
    case 'REJECTED':
      return KycDocumentStatus.rejected;
    case 'NOT_UPLOADED':
    default:
      return KycDocumentStatus.notUploaded;
  }
}
