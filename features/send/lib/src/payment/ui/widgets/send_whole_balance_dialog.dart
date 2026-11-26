import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart' show Divider;

/// Display facts from one real whole-balance preview, shown in a bottom sheet.
/// The screen owner checks that preview is still current before applying MAX
/// after confirmation.
class SendWholeBalanceDialog extends StatelessWidget {
  const SendWholeBalanceDialog({
    super.key,
    required this.title,
    required this.description,
    required this.balanceLabel,
    required this.balance,
    required this.feeLabel,
    required this.fee,
    required this.receivesLabel,
    required this.receives,
    required this.closeLabel,
    required this.sendAllLabel,
    required this.onClose,
    required this.onSendAll,
    this.receivesEquivalent,
  });

  final String title;
  final String description;
  final String balanceLabel;
  final Widget balance;
  final String feeLabel;
  final Widget fee;
  final String receivesLabel;
  final Widget receives;

  /// The recipient's amount in the display currency, under it.
  final String? receivesEquivalent;
  final String closeLabel;
  final String sendAllLabel;
  final VoidCallback onClose;
  final VoidCallback? onSendAll;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        BullSpacing.md,
        BullSpacing.md,
        BullSpacing.md,
        BullSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: context.bullType.subtitle.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              BullInlineIconButton(
                onPressed: onClose,
                tooltip: closeLabel,
                icon: const BullIcon(BullIcons.close),
              ),
            ],
          ),
          const Gap(BullSpacing.sm),
          Text(
            description,
            style: context.bullType.label.copyWith(
              color: context.bull.textMuted,
            ),
          ),
          const Gap(BullSpacing.md),
          _PreviewRow(label: balanceLabel, value: balance),
          const Gap(BullSpacing.xs),
          _PreviewRow(label: feeLabel, value: fee),
          const Gap(BullSpacing.sm),
          Divider(height: 1, color: context.bull.border),
          const Gap(BullSpacing.sm),
          _PreviewRow(label: receivesLabel, value: receives, strong: true),
          if (receivesEquivalent case final fiat?)
            Text(
              fiat,
              textAlign: TextAlign.end,
              style: context.bullType.caption.copyWith(
                color: context.bull.textMuted,
              ),
            ),
          const Gap(BullSpacing.lg),
          BullButton.primary(label: sendAllLabel, onPressed: onSendAll),
        ],
      ),
    ),
  );
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
    this.strong = false,
  });
  final String label;
  final Widget value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      label,
      style: strong
          ? context.bullType.body.copyWith(fontWeight: FontWeight.w700)
          : context.bullType.label.copyWith(color: context.bull.textMuted),
    );
    if (MediaQuery.textScalerOf(context).scale(14) > 17) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const Gap(BullSpacing.xxs),
          Align(alignment: Alignment.centerRight, child: value),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: title),
        const Gap(BullSpacing.xs),
        value,
      ],
    );
  }
}
