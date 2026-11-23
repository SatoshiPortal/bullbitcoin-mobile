import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient_type.dart';
import 'package:bb_mobile/features/recipients/public/recipient_selection.dart';
import 'package:flutter/widgets.dart';

extension RecipientTypeL10n on RecipientType {
  String label(BuildContext context) => switch (this) {
    RecipientType.interacEmailCad => context.loc.recipientsTypeInteracEmail,
    RecipientType.billPaymentCad => context.loc.recipientsTypeBillPayment,
    RecipientType.bankTransferCad => context.loc.recipientsTypeBankTransfer,
    RecipientType.sepaEur => context.loc.recipientsTypeSepa,
    RecipientType.confidentialSepaEur =>
      context.loc.recipientsTypeConfidentialSepa,
    RecipientType.speiClabeMxn => context.loc.recipientsTypeSpeiClabe,
    RecipientType.speiSmsMxn => context.loc.recipientsTypeSpeiSms,
    RecipientType.speiCardMxn => context.loc.recipientsTypeSpeiCard,
    RecipientType.sinpeIbanUsd => context.loc.recipientsTypeSinpeIbanUsd,
    RecipientType.sinpeIbanCrc => context.loc.recipientsTypeSinpeIbanCrc,
    RecipientType.sinpeMovilCrc => context.loc.recipientsTypeSinpeMovil,
    RecipientType.bankAccountArgentina =>
      context.loc.recipientsTypeBankAccountAr,
    RecipientType.pseColombia => context.loc.recipientsTypeBankAccountCo,
    RecipientType.nequiColombia => context.loc.recipientsTypeNequi,
  };
}

extension RecipientSelectionL10n on RecipientSelection {
  ({String label, String? value}) accountDetail(BuildContext context) =>
      switch (type) {
        RecipientType.interacEmailCad => (
          label: context.loc.recipientsInfoEmail,
          value: email,
        ),
        RecipientType.billPaymentCad => (
          label: context.loc.recipientsFieldAccountNumber,
          value: payeeAccountNumber,
        ),
        RecipientType.bankTransferCad => (
          label: context.loc.recipientsInfoAccount,
          value: [
            institutionNumber,
            transitNumber,
            accountNumber,
          ].map((part) => part ?? '').join('-'),
        ),
        RecipientType.sepaEur ||
        RecipientType.confidentialSepaEur ||
        RecipientType.sinpeIbanUsd ||
        RecipientType.sinpeIbanCrc => (
          label: context.loc.recipientsFieldIban,
          value: iban,
        ),
        RecipientType.speiClabeMxn => (
          label: context.loc.recipientsFieldClabe,
          value: clabe,
        ),
        RecipientType.speiSmsMxn ||
        RecipientType.sinpeMovilCrc ||
        RecipientType.nequiColombia => (
          label: context.loc.recipientsInfoPhone,
          value: phoneNumber,
        ),
        RecipientType.speiCardMxn => (
          label: context.loc.recipientsInfoCard,
          value: debitcard,
        ),
        RecipientType.bankAccountArgentina => (
          label: context.loc.recipientsFieldCvuCbu,
          value: bankAccount,
        ),
        RecipientType.pseColombia => (
          label: context.loc.recipientsFieldAccountNumber,
          value: bankAccount,
        ),
      };
}
