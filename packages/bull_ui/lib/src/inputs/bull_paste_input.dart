import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

/// A read-only field with a paste button that fills it from the clipboard —
/// duplicated from `core/widgets/inputs/paste_input.dart`.
class BullPasteInput extends StatelessWidget {
  const BullPasteInput({
    super.key,
    required this.text,
    required this.onChanged,
    this.hint = 'Paste a payment address or invoice',
  });

  /// The current value (controlled by the parent).
  final String text;

  /// Placeholder shown when [text] is empty.
  final String hint;

  /// Fired with the pasted clipboard contents.
  final Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          const Gap(15),
          Expanded(
            child: text.isEmpty
                ? BullText(
                    hint,
                    style: BullTextStyles.caption,
                    color: colors.onSurface,
                  )
                : BullText(
                    text.trim(),
                    style: BullTextStyles.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    color: colors.onSurface,
                  ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            icon: Icon(Icons.paste_sharp, color: colors.onSurface),
            onPressed: () {
              Clipboard.getData(Clipboard.kTextPlain).then((value) {
                if (value != null) {
                  onChanged(value.text ?? '');
                }
              });
            },
          ),
          const Gap(8),
        ],
      ),
    );
  }
}
