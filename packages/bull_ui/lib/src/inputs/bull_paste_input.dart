import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:bull_ui/src/layout/gap.dart';

/// A read-only field with a paste button that fills it from the clipboard.
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
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(context.bullShapes.input),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          const Gap(15),
          Expanded(
            child: text.isEmpty
                ? BullText(
                    hint,
                    style: context.bullType.caption,
                    color: colors.onSurface,
                  )
                : Text(
                    text.trim(),
                    style: context.bullType.body
                        .copyWith(fontWeight: FontWeight.w500)
                        .copyWith(color: colors.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
