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
      // TODO: Use localization labels instead of hardcoded strings.
      // CANADA types
      RecipientType.interacEmailCad => 'Interac e-Transfer',
      RecipientType.billPaymentCad => 'Bill Payment',
      RecipientType.bankTransferCad => 'Bank Transfer',
      // EUROPE types
      RecipientType.sepaEur => 'SEPA Transfer',
      // MEXICO types
      RecipientType.speiClabeMxn => 'SPEI CLABE',
      RecipientType.speiSmsMxn => 'SPEI SMS',
      RecipientType.speiCardMxn => 'SPEI Card',
      // COSTA RICA types
      RecipientType.sinpeIbanUsd => 'SINPE IBAN (USD)',
      RecipientType.sinpeIbanCrc => 'SINPE IBAN (CRC)',
      RecipientType.sinpeMovilCrc => 'SINPE Móvil',
      // ARGENTINA types
      RecipientType.cbuCvuArgentina => 'CBU/CVU Argentina',
      // TODO: Handle this case.
      RecipientType.pseColombia => 'Bank Account COP',
    }, style: style);
  }
}
