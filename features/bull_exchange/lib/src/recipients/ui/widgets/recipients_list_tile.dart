import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_exchange/src/recipients/presentation/payout_rail_l10n.dart';
import 'package:bull_exchange/src/recipients/public/recipient_view_model.dart';

class RecipientsListTile extends StatelessWidget {
  final RecipientViewModel recipient;
  final bool selected;
  final VoidCallback? onTap;

  const RecipientsListTile({
    super.key,
    required this.recipient,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = recipient.displayName;

    return MergeSemantics(
      child: Semantics(
        checked: selected,
        inMutuallyExclusiveGroup: true,
        enabled: onTap != null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: BullBorderedTile(
            onTap: onTap,
            backgroundColor: selected ? context.bull.surfaceContainer : null,
            child: Column(
              crossAxisAlignment: .start,
              mainAxisSize: .min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name ?? '-',
                        style: context.bullType.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Gap(8),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: selected
                          ? BullIcon(
                              BullIcons.checkCircle,
                              color: context.bull.primary,
                            )
                          : null,
                    ),
                  ],
                ),
                const Gap(8),
                Text(
                  recipient.rail.label(context),
                  style: context.bullType.body,
                ),
                for (final row in recipient.accountRows)
                  _InfoRow(label: row.field.label(context), value: row.value),
                if (recipient.label != null)
                  _InfoRow(
                    label: context.loc.recipientsInfoLabel,
                    value: recipient.label,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '$label: ${value?.isNotEmpty == true ? value : '-'}',
        style: context.bullType.body,
      ),
    );
  }
}
