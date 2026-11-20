import 'package:bull_ui/bull_ui.dart';

/// Shared mono/multi settings content. The owner applies each change and owns
/// navigation into the custom fee and change subviews.
class SendPaymentSettings extends StatelessWidget {
  const SendPaymentSettings({
    super.key,
    required this.title,
    required this.closeLabel,
    required this.feeLabel,
    required this.feeChoices,
    required this.selectedFee,
    required this.feeDetail,
    required this.editLabel,
    required this.rbfLabel,
    required this.replaceByFee,
    required this.multipleLabel,
    required this.multipleRecipients,
    required this.coinsLabel,
    required this.onClose,
    required this.onFeeSelected,
    required this.onReplaceByFee,
    required this.onMultipleRecipients,
    required this.onCoins,
    this.onCustomFeeEdit,
    this.change,
  });

  final String title;
  final String closeLabel;
  final String feeLabel;
  final Set<String> feeChoices;
  final String selectedFee;
  final Widget feeDetail;
  final String editLabel;
  final String rbfLabel;
  final bool replaceByFee;
  final String multipleLabel;
  final bool multipleRecipients;
  final String coinsLabel;
  final VoidCallback onClose;
  final ValueChanged<String> onFeeSelected;
  final ValueChanged<bool>? onReplaceByFee;
  final ValueChanged<bool>? onMultipleRecipients;
  final VoidCallback? onCoins;
  final VoidCallback? onCustomFeeEdit;
  final Widget? change;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: BullSpacing.md),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SizedBox(width: BullSpacing.xxl),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: context.bullType.subtitle,
              ),
            ),
            BullInlineIconButton(
              onPressed: onClose,
              tooltip: closeLabel,
              icon: const BullIcon(BullIcons.close),
            ),
          ],
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Gap(BullSpacing.md),
                Row(
                  children: [
                    const BullIcon(BullIcons.schedule),
                    const Gap(BullSpacing.xs),
                    Expanded(
                      child: Text(feeLabel, style: context.bullType.body),
                    ),
                  ],
                ),
                const Gap(BullSpacing.sm),
                BullSegmented(
                  items: feeChoices,
                  initialValue: selectedFee,
                  onSelected: onFeeSelected,
                  height: BullSpacing.xxl,
                  fitLabels: true,
                ),
                const Gap(BullSpacing.xs),
                feeDetail,
                if (onCustomFeeEdit case final edit?)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: BullInlineTextButton(
                      onPressed: edit,
                      child: Text(
                        editLabel,
                        style: context.bullType.label.copyWith(
                          color: context.bull.primary,
                        ),
                      ),
                    ),
                  ),
                if (change case final destination?) ...[
                  const Gap(BullSpacing.lg),
                  destination,
                ],
                const Gap(BullSpacing.md),
                _SettingSwitch(
                  label: rbfLabel,
                  value: replaceByFee,
                  onChanged: onReplaceByFee,
                ),
                _SettingSwitch(
                  label: multipleLabel,
                  value: multipleRecipients,
                  onChanged: onMultipleRecipients,
                ),
                const Gap(BullSpacing.md),
                Semantics(
                  button: true,
                  enabled: onCoins != null,
                  label: coinsLabel,
                  excludeSemantics: true,
                  onTap: onCoins,
                  child: GestureDetector(
                    onTap: onCoins,
                    child: Container(
                      color: context.bull.transparent,
                      constraints: const BoxConstraints(
                        minHeight: BullSpacing.xxl,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              coinsLabel,
                              style: context.bullType.body,
                            ),
                          ),
                          const BullIcon(BullIcons.chevronRight),
                        ],
                      ),
                    ),
                  ),
                ),
                const Gap(BullSpacing.lg),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    toggled: value,
    enabled: onChanged != null,
    excludeSemantics: true,
    onTap: onChanged == null ? null : () => onChanged?.call(!value),
    child: GestureDetector(
      onTap: onChanged == null ? null : () => onChanged?.call(!value),
      child: Container(
        color: context.bull.transparent,
        constraints: const BoxConstraints(minHeight: BullSpacing.xxl),
        padding: const EdgeInsets.symmetric(vertical: BullSpacing.xs),
        child: Row(
          children: [
            Expanded(child: Text(label, style: context.bullType.body)),
            BullSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    ),
  );
}
