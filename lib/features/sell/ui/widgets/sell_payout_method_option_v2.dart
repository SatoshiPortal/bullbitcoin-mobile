import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart'
    show Material, RadioListTile, RoundedRectangleBorder;

class SellPayoutMethodOptionV2<T> extends StatelessWidget {
  final T value;
  final bool selected;
  final bool enabled;
  final String title;
  final String description;
  final String? tag;

  const SellPayoutMethodOptionV2({
    required this.value,
    required this.selected,
    required this.enabled,
    required this.title,
    required this.description,
    this.tag,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Material(
      color: selected ? colors.primary.withValues(alpha: 0.08) : colors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: selected ? colors.primary : colors.border),
        borderRadius: BorderRadius.circular(BullRadius.xxs),
      ),
      child: RadioListTile<T>(
        value: value,
        enabled: enabled,
        activeColor: colors.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        title: Row(
          children: [
            Expanded(child: BullText(title, style: context.bullText.bodyLarge)),
            if (tag case final tag?) ...[
              const Gap(8),
              BullOptionsTag(text: tag),
            ],
          ],
        ),
        subtitle: description.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 4),
                child: BullText(
                  description,
                  style: context.bullText.bodySmall,
                  color: colors.textMuted,
                ),
              ),
      ),
    );
  }
}
