import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bull_ui/bull_ui.dart';

class SellPayoutDetailsV2 extends StatelessWidget {
  final RecipientSelection recipient;

  const SellPayoutDetailsV2({required this.recipient, super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      BullDetailsTableItem(
        label: context.loc.recipientsPayoutMethod,
        displayValue: recipient.type == RecipientType.confidentialSepaEur
            ? context.loc.recipientsTypeConfidentialSepa
            : context.loc.fundExchangeMethodInstantSepa,
      ),
      BullDetailsTableItem(
        label: context.loc.sellPayoutRecipient,
        displayValue: recipient.displayName,
      ),
      BullDetailsTableItem(
        label: context.loc.recipientsFieldBankAccountIban,
        displayValue: recipient.iban,
        copyValue: recipient.iban,
        copiedMessage: context.loc.copiedToClipboard,
      ),
    ],
  );
}
