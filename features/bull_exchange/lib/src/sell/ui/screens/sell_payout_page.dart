import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/sell/domain/sell_state.dart';
import 'package:bull_exchange/src/sell/domain/sell_event.dart';
import 'package:bull_ui/bull_ui.dart' show BullScrollableColumn, Gap;
import 'package:material_ui/material_ui.dart';

/// Where the sale's fiat goes: the account balance or a recipient.
class SellPayoutPage extends StatelessWidget {
  const SellPayoutPage({super.key, required this.onEvent});

  final void Function(SellFlowEvent event) onEvent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.sellPayoutTitle),
        leading: BackButton(onPressed: () => onEvent(const SellBackPressed())),
      ),
      body: SafeArea(
        child: BullScrollableColumn(
          padding: const EdgeInsets.all(16),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(context.loc.sellPayoutBalance),
              subtitle: Text(context.loc.sellBalanceWillBeCredited),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  onEvent(const SellPayoutPicked(SellPayoutChoice.balance)),
            ),
            const Gap(8),
            ListTile(
              title: Text(context.loc.sellPayoutRecipient),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  onEvent(const SellPayoutPicked(SellPayoutChoice.recipient)),
            ),
          ],
        ),
      ),
    );
  }
}
