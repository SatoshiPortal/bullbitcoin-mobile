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
      RecipientType.interacEmailCad => 'Interac Email Form',
      RecipientType.billPaymentCad => 'Bill Payment Form',
      RecipientType.bankTransferCad => 'Bank Transfer Form',
      // EUROPE types
      RecipientType.sepaEur => 'SEPA Form',
      // MEXICO types
      RecipientType.speiClabeMxn => 'SPEI CLABE Form',
      RecipientType.speiSmsMxn => 'SPEI SMS Form',
      RecipientType.speiCardMxn => 'SPEI Card Form',
      // COSTA RICA types
      RecipientType.sinpeIbanUsd => 'SINPE IBAN USD Form',
      RecipientType.sinpeIbanCrc => 'SINPE IBAN CRC Form',
      RecipientType.sinpeMovilCrc => 'SINPE Móvil CRC Form',
      // ARGENTINA types
      RecipientType.cbuCvuArgentina => 'CBU/CVU Argentina Form',
    }, style: style);
  }
}
