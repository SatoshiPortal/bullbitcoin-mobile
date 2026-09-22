import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/sepa_payment_option.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/sepa_virtual_payee_status.dart';
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
    bool? isOwner,
    String? bankAccount,
    @Default(SepaVirtualPayeeStatus.absent)
    SepaVirtualPayeeStatus virtualPayeeStatus,
    @Default({SepaPaymentOption.regular}) Set<SepaPaymentOption> paymentOptions,
  }) = _RecipientViewModel;
  const RecipientViewModel._();

  String get jurisdictionCode => type.jurisdictionCode;
  String get currencyCode => type.currencyCode;
  bool get isVirtualPayeeActive => virtualPayeeStatus.isActive;
  bool get hasVirtualPayee => virtualPayeeStatus.exists;
  bool get supportsRegularSepa =>
      paymentOptions.contains(SepaPaymentOption.regular) ||
      paymentOptions.contains(SepaPaymentOption.largeValue);

  String? get displayName {
    if (isCorporate == true &&
        corporateName != null &&
        corporateName!.isNotEmpty) {
      return corporateName!;
    }

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
      case RecipientType.confidentialSepaEur:
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
