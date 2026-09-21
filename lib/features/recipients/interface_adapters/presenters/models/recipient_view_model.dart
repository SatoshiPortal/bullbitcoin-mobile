import 'package:bb_mobile/features/recipients/application/dtos/recipient_dto.dart';
import 'package:bb_mobile/features/recipients/application/dtos/recipient_details_dto.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'recipient_view_model.freezed.dart';

@Freezed(toStringOverride: false)
sealed class RecipientViewModel with _$RecipientViewModel {
  const factory RecipientViewModel({
    required String id,
    required RecipientType type,
    String? name,
    String? firstname,
    String? lastname,
    String? email,
    String? securityQuestion,
    String? securityAnswer,
    bool? isCorporate,
    String? corporateName,
    String? ownerName,
    String? label,
    String? payeeName,
    String? payeeCode,
    String? payeeAccountNumber,
    String? institutionNumber,
    String? institutionCode,
    String? transitNumber,
    String? accountNumber,
    String? defaultComment,
    String? iban,
    String? clabe,
    String? phoneNumber,
    String? debitcard,
    bool? isOwner,
    String? bankAccount,
    String? bankCode,
    String? bankName,
    String? accountType,
    String? documentId,
    String? documentType,
  }) = _RecipientViewModel;
  const RecipientViewModel._();

  factory RecipientViewModel.fromDto(RecipientDto dto) {
    return _fromDetailsDto(
      id: dto.recipientId,
      type: dto.recipientType,
      details: dto.details,
      isOwner: dto.isOwner,
    );
  }

  factory RecipientViewModel.fromDetails({
    required String id,
    required RecipientDetails details,
  }) {
    final dto = RecipientDetailsDto.fromDomain(details);
    return _fromDetailsDto(
      id: id,
      type: details.type,
      details: dto,
      isOwner: details.isOwner,
    );
  }

  String get jurisdictionCode => type.jurisdictionCode;
  String get currencyCode => type.currencyCode;
  bool get requiresInteracSecurityDetails =>
      type == RecipientType.interacEmailCad;

  String? get displayName {
    // Check corporate first for all types
    if (isCorporate == true &&
        corporateName != null &&
        corporateName!.isNotEmpty) {
      return corporateName!;
    }

    // Type-specific logic
    switch (type) {
      case RecipientType.interacEmailCad:
        if (name != null && name!.isNotEmpty) return name!;
        if (firstname != null && lastname != null) {
          return '$firstname $lastname';
        }
        if (firstname != null) return firstname!;
        if (lastname != null) return lastname!;
        if (email != null) return email!;
        return null;

      case RecipientType.billPaymentCad:
        if (payeeName != null && payeeName!.isNotEmpty) return payeeName!;
        if (label != null && label!.isNotEmpty) return label!;
        return null;

      case RecipientType.bankTransferCad:
        if (name != null && name!.isNotEmpty) return name!;
        if (ownerName != null && ownerName!.isNotEmpty) return ownerName!;
        if (firstname != null && lastname != null) {
          return '$firstname $lastname';
        }
        if (firstname != null) return firstname!;
        if (lastname != null) return lastname!;
        if (label != null && label!.isNotEmpty) return label!;
        return null;

      case RecipientType.sepaEur:
        if (name != null && name!.isNotEmpty) return name!;
        if (firstname != null && lastname != null) {
          return '$firstname $lastname';
        }
        if (firstname != null) return firstname!;
        if (lastname != null) return lastname!;
        if (label != null && label!.isNotEmpty) return label!;
        return null;

      case RecipientType.speiClabeMxn:
        if (name != null && name!.isNotEmpty) return name!;
        if (firstname != null && lastname != null) {
          return '$firstname $lastname';
        }
        if (firstname != null) return firstname!;
        if (lastname != null) return lastname!;
        if (label != null && label!.isNotEmpty) return label!;
        return null;

      case RecipientType.speiSmsMxn:
        if (name != null && name!.isNotEmpty) return name!;
        if (firstname != null && lastname != null) {
          return '$firstname $lastname';
        }
        if (firstname != null) return firstname!;
        if (lastname != null) return lastname!;
        if (label != null && label!.isNotEmpty) return label!;
        return null;

      case RecipientType.speiCardMxn:
        if (name != null && name!.isNotEmpty) return name!;
        if (firstname != null && lastname != null) {
          return '$firstname $lastname';
        }
        if (firstname != null) return firstname!;
        if (lastname != null) return lastname!;
        if (label != null && label!.isNotEmpty) return label!;
        return null;

      // ownerName is often absent for the SINPE types (#2529), so fall all the
      // way back to the account identifier rather than showing nothing.
      case RecipientType.sinpeIbanUsd:
      case RecipientType.sinpeIbanCrc:
        if (ownerName != null && ownerName!.isNotEmpty) return ownerName!;
        if (label != null && label!.isNotEmpty) return label!;
        if (iban != null && iban!.isNotEmpty) return iban!;
        return null;

      case RecipientType.sinpeMovilCrc:
        if (ownerName != null && ownerName!.isNotEmpty) return ownerName!;
        if (label != null && label!.isNotEmpty) return label!;
        if (phoneNumber != null && phoneNumber!.isNotEmpty) {
          return phoneNumber!;
        }
        return null;
      case RecipientType.bankAccountArgentina:
        if (name != null && name!.isNotEmpty) return name!;
        if (label != null && label!.isNotEmpty) return label!;
        return null;
      case RecipientType.pseColombia:
        return name;
      case RecipientType.nequiColombia:
        return name;
    }
  }
}

RecipientViewModel _fromDetailsDto({
  required String id,
  required RecipientType type,
  required RecipientDetailsDto details,
  required bool? isOwner,
}) {
  return RecipientViewModel(
    id: id,
    type: type,
    name: details.name,
    firstname: details.firstname,
    lastname: details.lastname,
    email: details.email,
    securityQuestion: details.securityQuestion,
    securityAnswer: details.securityAnswer,
    isCorporate:
        details.isCorporate ??
        (type == RecipientType.sepaEur &&
            (details.corporateName?.isNotEmpty ?? false)),
    corporateName: details.corporateName,
    ownerName: details.ownerName,
    label: details.label,
    payeeName: details.payeeName,
    payeeCode: details.payeeCode,
    payeeAccountNumber: details.payeeAccountNumber,
    institutionNumber: details.institutionNumber,
    institutionCode: details.institutionCode,
    transitNumber: details.transitNumber,
    accountNumber: details.accountNumber,
    defaultComment: details.defaultComment,
    iban: details.iban,
    clabe: details.clabe,
    phoneNumber:
        details.phoneNumber ??
        details.phone ??
        (type == RecipientType.nequiColombia ? details.bankAccount : null),
    debitcard: details.debitcard,
    isOwner: isOwner,
    bankAccount: details.bankAccount ?? details.claveUniform,
    bankCode: details.bankCode,
    bankName: details.bankName,
    accountType: details.accountType,
    documentId: details.documentId,
    documentType: details.documentType,
  );
}
