import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart' show BullInputText, Gap;

class LabeledTextInput extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final Function(String)? onChanged;
  final int? maxLines;
  final FocusNode? focusNode;

  const LabeledTextInput({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint = '',
    this.maxLines,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        BBText(
          label,
          style: context.font.labelMedium?.copyWith(
            fontWeight: .w700,
            color: context.appColors.text,
            letterSpacing: 0,
            fontSize: 14,
          ),
        ),
        const Gap(8),
        Container(
          decoration: BoxDecoration(
            color: context.appColors.surface,
            borderRadius: BorderRadius.circular(2.76),
            border: Border.all(color: context.appColors.border, width: 0.69),
            boxShadow: [
              BoxShadow(
                color: context.appColors.border,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: BullInputText(
            value: value,
            onChanged: onChanged ?? (_) {},
            disabled: onChanged == null,
            style: context.font.bodySmall?.copyWith(
              fontWeight: .w700,
              fontSize: 14,
              color: context.appColors.text,
            ),
            hintStyle: context.font.bodySmall?.copyWith(
              fontWeight: .w700,
              fontSize: 14,
              color: context.appColors.textMuted,
            ),
            hint: hint,
            hideBorder: true,
            maxLines: maxLines,
            focusNode: focusNode,
          ),
        ),
      ],
    );
  }
}
