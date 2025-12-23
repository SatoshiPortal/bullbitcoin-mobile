import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

class PasteInput extends StatelessWidget {
  const PasteInput({
    super.key,
    required this.text,
    required this.onChanged,
    this.hint = 'Paste a payment address or invoice',
  });

  final String text;
  final String hint;
  final Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appColors.border),
      ),
      child: Row(
        children: [
          const Gap(15),
          Expanded(
            child:
                text.isEmpty
                    ? BBText(
                      hint,
                      style: context.font.labelSmall,
                      color: context.appColors.textMuted,
                    )
                    : BBText(
                      text.trim(),
                      style: context.font.bodyLarge,
                      color: context.appColors.text,
                    ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            icon: Icon(Icons.paste_sharp, color: context.appColors.text),
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
