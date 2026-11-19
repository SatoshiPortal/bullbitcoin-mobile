import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient_type.dart';
import 'package:material_ui/material_ui.dart';

/// The translated name of [recipientType].
String recipientTypeLabel(BuildContext context, RecipientType recipientType) {
  return switch (recipientType) {
    // CANADA types
    RecipientType.interacEmailCad => context.loc.recipientsTypeInteracEmail,
    RecipientType.billPaymentCad => context.loc.recipientsTypeBillPayment,
    RecipientType.bankTransferCad => context.loc.recipientsTypeBankTransfer,
    // EUROPE types
    RecipientType.sepaEur => context.loc.recipientsTypeSepa,
    RecipientType.confidentialSepaEur =>
      context.loc.recipientsTypeConfidentialSepa,
    // MEXICO types
    RecipientType.speiClabeMxn => context.loc.recipientsTypeSpeiClabe,
    RecipientType.speiSmsMxn => context.loc.recipientsTypeSpeiSms,
    RecipientType.speiCardMxn => context.loc.recipientsTypeSpeiCard,
    // COSTA RICA types
    RecipientType.sinpeIbanUsd => context.loc.recipientsTypeSinpeIbanUsd,
    RecipientType.sinpeIbanCrc => context.loc.recipientsTypeSinpeIbanCrc,
    RecipientType.sinpeMovilCrc => context.loc.recipientsTypeSinpeMovil,
    // ARGENTINA types
    RecipientType.bankAccountArgentina =>
      context.loc.recipientsTypeBankAccountAr,
    RecipientType.pseColombia => context.loc.recipientsTypeBankAccountCo,
    RecipientType.nequiColombia => context.loc.recipientsTypeNequi,
  };
}
