import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bull_ui/bull_ui.dart';

class SellPayoutDetails extends StatelessWidget {
  final RecipientSelection recipient;

  const SellPayoutDetails({required this.recipient, super.key});

  @override
  Widget build(BuildContext context) {
    final account = recipient.accountDetail(context);
    return Column(
      children: [
        BullDetailsTableItem(
          label: context.loc.recipientsPayoutMethod,
          displayValue: recipient.type == RecipientType.sepaEur
              ? context.loc.fundExchangeMethodInstantSepa
              : recipient.type.label(context),
        ),
        BullDetailsTableItem(
          label: context.loc.sellPayoutRecipient,
          displayValue: recipient.displayName,
        ),
        BullDetailsTableItem(
          label: account.label,
          displayValue: account.value,
          copyValue: account.value,
          copiedMessage: context.loc.copiedToClipboard,
        ),
      ],
    );
  }
}
