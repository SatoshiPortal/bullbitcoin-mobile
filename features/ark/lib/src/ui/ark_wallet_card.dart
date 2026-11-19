import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';

import '../domain/ark_display_data_port.dart';
import '../presentation/ark_l10n.dart';
import 'ark_amount.dart';

/// A dashboard entry, not an account initializer or a funding capability.
class ArkWalletCard extends StatelessWidget {
  final ArkSnapshot? snapshot;
  final VoidCallback onOpen;
  final ArkDisplayData? displayData;
  const ArkWalletCard({
    super.key,
    this.snapshot,
    this.displayData,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final observation = snapshot;
    final amount = observation != null && !observation.stale
        ? observation.spendable
        : null;
    return BullBorderedTile(
      onTap: onOpen,
      padding: EdgeInsets.zero,
      backgroundColor: context.bull.surface,
      child: Row(
        children: [
          Container(
            width: BullSpacing.xxs,
            height: BullSpacing.xxxl + BullSpacing.lg,
            color: context.bull.primary,
          ),
          const Gap(BullSpacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BullText(context.loc.title, role: BullTextRole.body),
                const Gap(BullSpacing.xxs),
                BullText(
                  context.loc.arkWalletSubtitle,
                  role: BullTextRole.label,
                  color: context.bull.textMuted,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              BullText(
                formatArkObservedSats(context, amount),
                role: BullTextRole.body,
              ),
              if (amount != null &&
                  observation != null &&
                  displayData?.account == observation.account)
                ArkFiatAmount(amount: amount, price: displayData?.price),
            ],
          ),
          const Gap(BullSpacing.sm),
          BullIcon(BullIcons.chevronRight, color: context.bull.textMuted),
          const Gap(BullSpacing.md),
        ],
      ),
    );
  }
}
