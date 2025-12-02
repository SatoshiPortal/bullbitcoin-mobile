import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class LabeledTextInput extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final Function(String)? onChanged;
  final int? maxLines;

  const LabeledTextInput({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint = '',
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          label,
          style: context.font.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
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
          child: BBInputText(
            value: value,
            onChanged: onChanged ?? (_) {},
            disabled: onChanged == null,
            style: context.font.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: context.appColors.text,
            ),
            hintStyle: context.font.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: context.appColors.textMuted,
            ),
            hint: hint,
            hideBorder: true,
            maxLines: maxLines,
          ),
        ),
      ],
    );
  }
}
