import 'package:bull_ui/src/inputs/bull_input_text.dart';
import 'package:bull_ui/src/inputs/labeled_input_frame.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:material_ui/material_ui.dart';

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
    this.controller,
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

  /// Optional external controller, for a caller that owns the field text (a
  /// form pushing a programmatic change back in). One is created when null.
  final TextEditingController? controller;

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
    return LabeledInputFrame(
      label: label,
      child: BullInputText(
        controller: controller,
        value: value,
        onChanged: onChanged ?? (_) {},
        disabled: onChanged == null,
        style: LabeledInputFrame.fieldStyle(context, colors.text),
        hintStyle: LabeledInputFrame.fieldStyle(context, colors.textMuted),
        hint: hint,
        hideBorder: true,
        maxLines: maxLines,
        enableSuggestions: enableSuggestions,
        autocorrect: autocorrect,
        smartQuotesType: smartQuotesType,
        smartDashesType: smartDashesType,
      ),
    );
  }
}
