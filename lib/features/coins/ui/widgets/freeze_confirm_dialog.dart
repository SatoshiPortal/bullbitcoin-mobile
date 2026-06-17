import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart';

/// Freeze confirmation modal (§14). Snowflake header, explanatory body, an
/// optional [BullInfoBar] warning when freezing would drop the spendable
/// balance to zero, and Cancel / Freeze buttons. Returns `true` from
/// [BullDialog.show] when the user confirms.
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
        Center(
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.info.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: BullIcon(BullIcons.acUnit, size: 22, color: colors.info),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          loc.coinsFreezeConfirmTitle(count),
          textAlign: TextAlign.center,
          style: context.bullText.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700, color: colors.text),
        ),
        const SizedBox(height: 8),
        Text(
          loc.coinsFreezeConfirmBody,
          textAlign: TextAlign.center,
          style: context.bullText.bodyMedium
              ?.copyWith(color: colors.textMuted),
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
              child: BullButton.big(
                label: loc.cancel,
                onPressed: onCancel,
                bgColor: colors.transparent,
                textColor: colors.text,
                outlined: true,
                borderColor: colors.outlineVariant,
                height: 46,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BullButton.big(
                label: loc.coinsFreeze,
                onPressed: onConfirm,
                bgColor: colors.primary,
                textColor: colors.onPrimary,
                height: 46,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
