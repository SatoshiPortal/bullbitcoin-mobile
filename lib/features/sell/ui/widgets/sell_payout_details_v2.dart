import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/lists/payment_detail_row.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bull_ui/bull_ui.dart';

class SellPayoutDetailsV2 extends StatelessWidget {
  final RecipientSelection recipient;

  const SellPayoutDetailsV2({required this.recipient, super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      PaymentDetailRow(
        title: context.loc.recipientsPayoutMethod,
        value: recipient.type == RecipientType.confidentialSepaEur
            ? context.loc.recipientsTypeConfidentialSepa
            : context.loc.fundExchangeMethodInstantSepa,
      ),
      PaymentDetailRow(
        title: context.loc.sellPayoutRecipient,
        value: recipient.displayName,
      ),
      PaymentDetailRow(
        title: context.loc.recipientsFieldBankAccountIban,
        value: recipient.iban,
        copyValue: recipient.iban,
      ),
    ],
  );
}
