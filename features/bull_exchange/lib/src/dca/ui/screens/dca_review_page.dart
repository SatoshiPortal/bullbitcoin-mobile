import 'package:bull_exchange/src/dca/presentation/dca_flow.dart';
import 'package:bull_exchange/src/dca/ui/widgets/dca_confirmation_detail_row.dart';
import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullFadingLinearProgress,
        BullScrollableColumn,
        BullTypographyX,
        Gap;
import 'package:exchange/exchange.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show FormatAmount;

/// The recurring buy before it is created: frequency, amount, balance, order
/// type, network and payout address, with Confirm.
class DcaReviewPage extends StatelessWidget {
  const DcaReviewPage({
    super.key,
    required this.plan,
    required this.onEvent,
    this.problem,
    this.busy = false,
  });

  final DcaPlan plan;
  final void Function(DcaFlowEvent event) onEvent;
  final String? problem;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final problem = this.problem;
    final divider = Divider(color: context.appColors.outline);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.dcaConfirmTitle),
        leading: BackButton(onPressed: () => onEvent(const DcaBackPressed())),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: BullFadingLinearProgress(
            height: 3,
            trigger: busy,
            backgroundColor: context.appColors.surface,
            foregroundColor: context.appColors.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: BullScrollableColumn(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Gap(24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                context.loc.dcaConfirmAutoMessage,
                style: context.bullType.body,
                textAlign: TextAlign.center,
              ),
            ),
            const Gap(24),
            DcaConfirmationDetailRow(
              label: context.loc.dcaConfirmFrequency,
              value: dcaFrequencyLabel(context, plan.frequency),
            ),
            divider,
            DcaConfirmationDetailRow(
              label: context.loc.dcaConfirmAmount,
              value: FormatAmount.fiat(plan.fiat, plan.currency.code),
            ),
            divider,
            DcaConfirmationDetailRow(
              label: context.loc.dcaConfirmPaymentMethod,
              value: context.loc.dcaConfirmPaymentBalance(
                plan.currency.code.toUpperCase(),
              ),
            ),
            divider,
            DcaConfirmationDetailRow(
              label: context.loc.dcaConfirmOrderType,
              value: context.loc.dcaConfirmOrderTypeValue,
            ),
            divider,
            DcaConfirmationDetailRow(
              label: context.loc.dcaConfirmNetwork,
              value: switch (plan.payout.network) {
                BtcNetwork.bitcoin => context.loc.dcaConfirmNetworkBitcoin,
                BtcNetwork.lightning => context.loc.dcaConfirmNetworkLightning,
                BtcNetwork.liquid => context.loc.dcaConfirmNetworkLiquid,
              },
            ),
            divider,
            DcaConfirmationDetailRow(
              label: switch (plan.payout.network) {
                BtcNetwork.lightning => context.loc.dcaConfirmLightningAddress,
                BtcNetwork.bitcoin ||
                BtcNetwork.liquid => context.loc.dcaConfirmPayoutAddress,
              },
              value: plan.payout.address,
            ),
            const Spacer(),
            if (problem != null) ...[
              Text(
                problem,
                style: context.bullType.label
                    .copyWith(fontWeight: FontWeight.w400)
                    .copyWith(color: context.appColors.error),
              ),
              const Gap(16),
            ],
            BullButton.primary(
              label: context.loc.dcaConfirmContinue,
              onPressed: busy ? null : () => onEvent(const DcaConfirmPressed()),
            ),
            const Gap(16),
          ],
        ),
      ),
    );
  }
}

String dcaFrequencyLabel(BuildContext context, DcaBuyFrequency frequency) =>
    switch (frequency) {
      DcaBuyFrequency.hourly => context.loc.dcaConfirmFrequencyHourly,
      DcaBuyFrequency.daily => context.loc.dcaConfirmFrequencyDaily,
      DcaBuyFrequency.weekly => context.loc.dcaConfirmFrequencyWeekly,
      DcaBuyFrequency.monthly => context.loc.dcaConfirmFrequencyMonthly,
    };
