import 'package:bb_mobile/ui/components/loading/loading_line_content.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

class CopyInput extends StatelessWidget {
  const CopyInput({
    super.key,
    required this.text,
    this.clipboardText,
    this.maxLines,
    this.overflow,
  });

  final String text;
  // In case it should be different from the shown text
  final String? clipboardText;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colour.onPrimary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colour.secondaryFixedDim),
      ),
      child: Row(
        children: [
          const Gap(15),
          Expanded(
            child:
                text.isEmpty
                    ? const LoadingLineContent(width: double.infinity)
                    : BBText(
                      text,
                      style: context.font.bodyLarge,
                      color: context.colour.secondary,
                      maxLines: maxLines,
                      overflow: overflow,
                    ),
          ),
          // Only show the copy button if there is something to copy
          if ((clipboardText == null && text.isNotEmpty) ||
              (clipboardText != null && clipboardText!.isNotEmpty))
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              icon: Icon(Icons.copy_sharp, color: context.colour.secondary),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: clipboardText ?? text));
              },
            ),
          const Gap(8),
        ],
      ),
    );
  }
}
