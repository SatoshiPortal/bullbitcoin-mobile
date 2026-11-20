import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/lists/payment_detail_row.dart';
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
        PaymentDetailRow(
          title: context.loc.recipientsPayoutMethod,
          value: recipient.type == RecipientType.sepaEur
              ? context.loc.fundExchangeMethodInstantSepa
              : recipient.type.label(context),
        ),
        PaymentDetailRow(
          title: context.loc.sellPayoutRecipient,
          value: recipient.displayName,
        ),
        PaymentDetailRow(
          title: account.label,
          value: account.value,
          copyValue: account.value,
        ),
      ],
    );
  }
}
