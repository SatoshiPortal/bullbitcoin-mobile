import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/inputs/bull_input_text.dart';
import 'package:bull_ui/src/layout/gap.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';

/// A [BullInputText] with a bold label above it, set in a bordered card with
/// a drop shadow.
///
/// A null [onChanged] renders the field disabled.
class BullLabeledTextInput extends StatelessWidget {
  const BullLabeledTextInput({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint = '',
    this.maxLines,
    this.enableSuggestions = true,
    this.autocorrect = true,
    this.smartQuotesType,
    this.smartDashesType,
  });

  /// Label shown above the field.
  final String label;

  /// The current value (the field is controlled by the parent).
  final String value;

  /// Placeholder text.
  final String hint;

  /// Fired on every change; null disables the field.
  final void Function(String)? onChanged;

  /// Maximum lines.
  final int? maxLines;

  /// Both default to true. Set them false for secrets: the IME's suggestion
  /// and autocorrect caches must never see the value.
  final bool enableSuggestions;
  final bool autocorrect;

  /// iOS Smart Punctuation, on by default. Disable both when the value must
  /// survive exactly as typed.
  final SmartQuotesType? smartQuotesType;
  final SmartDashesType? smartDashesType;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BullText(
          label,
          style: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.text,
            letterSpacing: 0,
            fontSize: 14,
          ),
        ),
        const Gap(8),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(2.76),
            border: Border.all(color: colors.border, width: 0.69),
            boxShadow: [
              BoxShadow(color: colors.border, offset: const Offset(0, 2)),
            ],
          ),
          child: BullInputText(
            value: value,
            onChanged: onChanged ?? (_) {},
            disabled: onChanged == null,
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: colors.text,
            ),
            hintStyle: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: colors.textMuted,
            ),
            hint: hint,
            hideBorder: true,
            maxLines: maxLines,
            enableSuggestions: enableSuggestions,
            autocorrect: autocorrect,
            smartQuotesType: smartQuotesType,
            smartDashesType: smartDashesType,
          ),
        ),
      ],
    );
  }
}
