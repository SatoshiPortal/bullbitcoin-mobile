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

  const LabeledTextInput({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint = '',
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
            color: context.colour.secondary,
            letterSpacing: 0,
            fontSize: 14,
          ),
        ),
        const Gap(8),
        Container(
          decoration: BoxDecoration(
            color: context.colour.onPrimary,
            borderRadius: BorderRadius.circular(2.76),
            border: Border.all(color: context.colour.surface, width: 0.69),
            boxShadow: [
              BoxShadow(
                color: context.colour.surface,
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
              color: context.colour.secondary,
            ),
            hintStyle: context.font.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: context.colour.surface,
            ),
            hint: hint,
            hideBorder: true,
          ),
        ),
      ],
    );
  }
}
