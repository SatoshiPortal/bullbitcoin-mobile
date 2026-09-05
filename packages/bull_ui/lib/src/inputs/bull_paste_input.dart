import 'package:bull_ui/src/inputs/bull_input_text.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// An editable text field with paste and optional scan actions.
class BullPasteInput extends StatelessWidget {
  const BullPasteInput({
    super.key,
    required this.text,
    required this.onChanged,
    required this.hint,
    this.onScan,
    this.onPasteError,
    this.enabled = true,
    this.minLines = 1,
    this.maxLines = 4,
  });

  /// The current value (controlled by the parent).
  final String text;

  /// Placeholder shown when [text] is empty.
  final String hint;

  /// Fired for both typed and pasted contents.
  final ValueChanged<String> onChanged;

  /// Displays a scanner supplied by the consuming feature.
  final VoidCallback? onScan;

  /// Reports clipboard failures without exposing pasted contents.
  final ValueChanged<Exception>? onPasteError;

  final bool enabled;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return BullInputText(
      value: text,
      hint: hint,
      disabled: !enabled,
      minLines: minLines,
      maxLines: maxLines,
      enableSuggestions: false,
      autocorrect: false,
      smartQuotesType: SmartQuotesType.disabled,
      smartDashesType: SmartDashesType.disabled,
      onChanged: onChanged,
      rightIcon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onScan != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.qr_code_scanner, color: colors.onSurface),
              onPressed: enabled ? onScan : null,
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.paste_sharp, color: colors.onSurface),
            onPressed: enabled ? _paste : null,
          ),
        ],
      ),
    );
  }

  Future<void> _paste() async {
    try {
      final value = await Clipboard.getData(Clipboard.kTextPlain);
      if (value?.text case final text?) onChanged(text);
    } on Exception catch (error) {
      onPasteError?.call(error);
    }
  }
}
