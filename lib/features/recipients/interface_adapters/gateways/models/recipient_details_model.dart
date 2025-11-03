import 'package:bb_mobile/features/recipients/application/dtos/recipient_details_dto.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'recipient_details_model.freezed.dart';
part 'recipient_details_model.g.dart';

/// MODEL: Flat structure for JSON serialization/deserialization of all recipient types
/// Maps directly to the API's JSON structure
@freezed
sealed class RecipientDetailsModel with _$RecipientDetailsModel {
  const factory RecipientDetailsModel({
    // discriminator
    required String recipientType, // e.g. 'INTERAC_EMAIL_CAD'
    // shared fields
    String? label,
    required bool isOwner,
    bool? isDefault,

    // Interac Email (CAD)
    String? email,
    String? name,
    String? securityQuestion,
    String? securityAnswer,

    // Bill Payment (CAD)
    String? payeeName,
    String? payeeCode,
    String? payeeAccountNumber,

    // Bank Transfer (CAD)
    String? institutionNumber,
    String? transitNumber,
    String? accountNumber,
    String? defaultComment,

    // SEPA (EUR)
    String? iban,
    bool? isCorporate,
    String? firstname,
    String? lastname,
    String? corporateName,

    // SPEI (MXN)
    String? clabe,
    String? institutionCode,
    String? phone,
    String? debitcard,

    // SINPE (CRC/USD)
    String? ownerName,
    String? phoneNumber,
  }) = _RecipientDetailsModel;

  factory RecipientDetailsModel.fromJson(Map<String, dynamic> json) =>
      _$RecipientDetailsModelFromJson(json);

  const RecipientDetailsModel._();

  /// Convert from domain value object to model
  factory RecipientDetailsModel.fromDomain(RecipientDetails details) {
    final type = details.type;

    return switch (type) {
      RecipientType.interacEmailCad => () {
        final d = details as InteracEmailCadDetails;
        return RecipientDetailsModel(
          recipientType: type.value,
          isOwner: d.isOwner,
          label: d.label,
          isDefault: d.isDefault,
          email: d.email,
          name: d.name,
          securityQuestion: d.securityQuestion,
          securityAnswer: d.securityAnswer,
        );
      }(),

      RecipientType.billPaymentCad => () {
        final d = details as BillPaymentCadDetails;
        return RecipientDetailsModel(
          recipientType: type.value,
          isOwner: d.isOwner,
          label: d.label,
          isDefault: d.isDefault,
          payeeName: d.payeeName,
          payeeCode: d.payeeCode,
          payeeAccountNumber: d.payeeAccountNumber,
        );
      }(),

      RecipientType.bankTransferCad => () {
        final d = details as BankTransferCadDetails;
        return RecipientDetailsModel(
          recipientType: type.value,
          isOwner: d.isOwner,
          label: d.label,
          isDefault: d.isDefault,
          institutionNumber: d.institutionNumber,
          transitNumber: d.transitNumber,
          accountNumber: d.accountNumber,
          name: d.name,
          defaultComment: d.defaultComment,
        );
      }(),

      RecipientType.sepaEur => () {
        final d = details as SepaEurDetails;
        return RecipientDetailsModel(
          recipientType: type.value,
          isOwner: d.isOwner,
          label: d.label,
          isDefault: d.isDefault,
          iban: d.iban,
          isCorporate: d.isCorporate,
          firstname: d.firstname,
          lastname: d.lastname,
          corporateName: d.corporateName,
        );
      }(),

      RecipientType.speiClabeMxn => () {
        final d = details as SpeiClabeMxnDetails;
        return RecipientDetailsModel(
          recipientType: type.value,
          isOwner: d.isOwner,
          label: d.label,
          isDefault: d.isDefault,
          clabe: d.clabe,
          name: d.name,
        );
      }(),

      RecipientType.speiSmsMxn => () {
        final d = details as SpeiSmsMxnDetails;
        return RecipientDetailsModel(
          recipientType: type.value,
          isOwner: d.isOwner,
          label: d.label,
          isDefault: d.isDefault,
          institutionCode: d.institutionCode,
          phone: d.phone,
          name: d.name,
        );
      }(),

      RecipientType.speiCardMxn => () {
        final d = details as SpeiCardMxnDetails;
        return RecipientDetailsModel(
          recipientType: type.value,
          isOwner: d.isOwner,
          label: d.label,
          isDefault: d.isDefault,
          institutionCode: d.institutionCode,
          debitcard: d.debitcard,
          name: d.name,
        );
      }(),

      RecipientType.sinpeIbanUsd => () {
        final d = details as SinpeIbanUsdDetails;
        return RecipientDetailsModel(
          recipientType: type.value,
          isOwner: d.isOwner,
          label: d.label,
          isDefault: d.isDefault,
          iban: d.iban,
          ownerName: d.ownerName,
        );
      }(),

      RecipientType.sinpeIbanCrc => () {
        final d = details as SinpeIbanCrcDetails;
        return RecipientDetailsModel(
          recipientType: type.value,
          isOwner: d.isOwner,
          label: d.label,
          isDefault: d.isDefault,
          iban: d.iban,
          ownerName: d.ownerName,
        );
      }(),

      RecipientType.sinpeMovilCrc => () {
        final d = details as SinpeMovilCrcDetails;
        return RecipientDetailsModel(
          recipientType: type.value,
          isOwner: d.isOwner,
          label: d.label,
          isDefault: d.isDefault,
          phoneNumber: d.phoneNumber,
          ownerName: d.ownerName,
        );
      }(),
    };
  }

  /// Convert from model to domain value object via DTO
  RecipientDetails toDomain() {
    // Use DTO as intermediate for validation
    final dto = RecipientDetailsDto(
      recipientType: recipientType,
      isOwner: isOwner,
      label: label,
      isDefault: isDefault,
      email: email,
      name: name,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
      payeeName: payeeName,
      payeeCode: payeeCode,
      payeeAccountNumber: payeeAccountNumber,
      institutionNumber: institutionNumber,
      transitNumber: transitNumber,
      accountNumber: accountNumber,
      defaultComment: defaultComment,
      iban: iban,
      isCorporate: isCorporate,
      firstname: firstname,
      lastname: lastname,
      corporateName: corporateName,
      clabe: clabe,
      institutionCode: institutionCode,
      phone: phone,
      debitcard: debitcard,
      ownerName: ownerName,
      phoneNumber: phoneNumber,
    );

    return dto.toDomain();
  }
}
