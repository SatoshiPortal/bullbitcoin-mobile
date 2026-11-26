import 'package:bull_ui/bull_ui.dart';

/// Display facts from one real whole-balance preview. The screen owner checks
/// that preview is still current before applying MAX after confirmation.
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
    required this.cancelLabel,
    required this.sendAllLabel,
    required this.onCancel,
    required this.onSendAll,
  });

  final String title;
  final String description;
  final String balanceLabel;
  final Widget balance;
  final String feeLabel;
  final Widget fee;
  final String receivesLabel;
  final Widget receives;
  final String cancelLabel;
  final String sendAllLabel;
  final VoidCallback onCancel;
  final VoidCallback? onSendAll;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: context.bullType.subtitle),
      const Gap(BullSpacing.sm),
      Text(description, style: context.bullType.body),
      const Gap(BullSpacing.lg),
      _PreviewRow(label: balanceLabel, value: balance),
      const Gap(BullSpacing.sm),
      _PreviewRow(label: feeLabel, value: fee),
      const Gap(BullSpacing.sm),
      _PreviewRow(label: receivesLabel, value: receives, strong: true),
      const Gap(BullSpacing.lg),
      Row(
        children: [
          Expanded(
            child: BullButton.secondary(
              label: cancelLabel,
              onPressed: onCancel,
            ),
          ),
          const Gap(BullSpacing.sm),
          Expanded(
            child: BullButton.primary(
              label: sendAllLabel,
              onPressed: onSendAll,
            ),
          ),
        ],
      ),
    ],
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
      style: context.bullType.label.copyWith(
        fontWeight: strong ? FontWeight.w500 : FontWeight.w400,
      ),
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
