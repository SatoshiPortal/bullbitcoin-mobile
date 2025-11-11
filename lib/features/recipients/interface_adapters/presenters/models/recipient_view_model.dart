import 'package:bb_mobile/features/recipients/application/dtos/recipient_dto.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'recipient_view_model.freezed.dart';

@freezed
sealed class RecipientViewModel with _$RecipientViewModel {
  const factory RecipientViewModel({
    required String id,
    required RecipientType type,
    String? name,
    String? firstname,
    String? lastname,
    String? email,
    bool? isCorporate,
    String? corporateName,
    String? ownerName,
    String? label,
    String? payeeName,
    String? payeeCode,
    String? payeeAccountNumber,
    String? institutionNumber,
    String? transitNumber,
    String? accountNumber,
    String? iban,
    String? clabe,
    String? phoneNumber,
    String? debitcard,
  }) = _RecipientViewModel;
  const RecipientViewModel._();

  factory RecipientViewModel.fromDto(RecipientDto dto) {
    return RecipientViewModel(
      id: dto.recipientId,
      type: dto.recipientType,
      name: dto.details.name,
      firstname: dto.details.firstname,
      lastname: dto.details.lastname,
      email: dto.details.email,
      isCorporate: dto.details.isCorporate,
      corporateName: dto.details.corporateName,
      ownerName: dto.details.ownerName,
      label: dto.details.label,
      payeeName: dto.details.payeeName,
      payeeCode: dto.details.payeeCode,
      payeeAccountNumber: dto.details.payeeAccountNumber,
      institutionNumber: dto.details.institutionNumber,
      transitNumber: dto.details.transitNumber,
      accountNumber: dto.details.accountNumber,
      iban: dto.details.iban,
      clabe: dto.details.clabe,
      phoneNumber: dto.details.phoneNumber,
      debitcard: dto.details.debitcard,
    );
  }

  String get jurisdictionCode => type.jurisdictionCode;
  String get currencyCode => type.currencyCode;

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

      case RecipientType.sinpeIbanUsd:
        if (ownerName != null && ownerName!.isNotEmpty) return ownerName!;
        if (label != null && label!.isNotEmpty) return label!;
        return null;

      case RecipientType.sinpeIbanCrc:
        if (ownerName != null && ownerName!.isNotEmpty) return ownerName!;
        if (label != null && label!.isNotEmpty) return label!;
        return null;

      case RecipientType.sinpeMovilCrc:
        if (ownerName != null && ownerName!.isNotEmpty) return ownerName!;
        if (label != null && label!.isNotEmpty) return label!;
        return null;
      case RecipientType.cbuCvuArgentina:
        return null;
      case RecipientType.pseColombia:
        return null;
    }
  }
}
