import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:flutter/material.dart';

// Helper widget to avoid needing to repeat the mapping of the type with its
// translation label per recipient type in multiple places.
class RecipientTypeText extends StatelessWidget {
  const RecipientTypeText({super.key, required this.recipientType, this.style});

  final RecipientType recipientType;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(switch (recipientType) {
      // CANADA types
      RecipientType.interacEmailCad => context.loc.recipientsTypeInteracEmail,
      RecipientType.billPaymentCad => context.loc.recipientsTypeBillPayment,
      RecipientType.bankTransferCad => context.loc.recipientsTypeBankTransfer,
      // EUROPE types
      RecipientType.sepaEur => context.loc.recipientsTypeSepa,
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
    }, style: style);
  }
}
