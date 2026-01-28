import 'package:freezed_annotation/freezed_annotation.dart';

part 'virtual_iban_recipient.freezed.dart';

/// Entity representing a Virtual IBAN (Confidential SEPA) recipient.
///
/// This is used for the FR_VIRTUAL_ACCOUNT recipient type which provides
/// users with a personal virtual IBAN for private EUR deposits and withdrawals.
@freezed
sealed class VirtualIbanRecipient with _$VirtualIbanRecipient {
  const factory VirtualIbanRecipient({
    required String recipientId,
    String? iban,
    String? bicCode,
    String? bankAddress,
    String? ibanCountry,
    String? frAccountId,
    String? frUserId,
    String? frPayeeId,
    @Default(false) bool isOwner,
    String? createdAt,
    String? updatedAt,
  }) = _VirtualIbanRecipient;

  const VirtualIbanRecipient._();

  /// Returns true if the Virtual IBAN has been fully activated.
  /// A VIBAN is considered active when it has an IBAN, BIC code, and bank address.
  bool get isActive {
    final hasIban = iban != null && iban!.isNotEmpty;
    final hasBicCode = bicCode != null && bicCode!.isNotEmpty;
    final hasBankAddress = bankAddress != null && bankAddress!.isNotEmpty;

    return hasIban && hasBicCode && hasBankAddress;
  }

  /// Returns true if the VIBAN has been submitted but not yet activated.
  /// This means the recipient exists but doesn't have the banking details yet.
  bool get isPending => !isActive;
}


