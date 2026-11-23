import 'package:coins/src/coins_l10n.dart';
import 'package:bull_ui/bull_ui.dart';

/// Freeze confirmation modal (§14). Snowflake header, explanatory body, an
/// optional [BullInfoBar] warning when freezing would drop the spendable
/// balance to zero, and Cancel / Freeze buttons. Outcome is delivered via the
/// [onCancel] / [onConfirm] callbacks — [BullDialog.show] returns no value.
class FreezeConfirmDialog extends StatelessWidget {
  const FreezeConfirmDialog({
    super.key,
    required this.count,
    required this.makesSpendableZero,
    required this.onCancel,
    required this.onConfirm,
  });

  final int count;
  final bool makesSpendableZero;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final loc = context.loc;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.info.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: BullIcon(BullIcons.acUnit, size: 22, color: colors.info),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                loc.coinsFreezeConfirmTitle(count),
                style: context.bullType.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          loc.coinsFreezeConfirmBody,
          style: context.bullType.label.copyWith(
            fontWeight: FontWeight.w400,
            color: colors.textMuted,
          ),
        ),
        if (makesSpendableZero) ...[
          const SizedBox(height: 16),
          BullInfoBar(
            message: loc.coinsFreezeZeroWarning,
            tone: BullInfoTone.warning,
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: BullButton.secondary(
                label: loc.cancel,
                onPressed: onCancel,
                height: 46,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BullButton.primary(
                label: loc.coinsFreeze,
                onPressed: onConfirm,
                height: 46,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
