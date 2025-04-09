import 'package:bb_mobile/ui/components/loading/loading_line_content.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

class PasteInput extends StatelessWidget {
  const PasteInput({
    super.key,
    required this.text,
    required this.onChanged,
  });

  final String text;
  final Function(String) onChanged;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: context.colour.onPrimary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.colour.secondaryFixedDim,
        ),
      ),
      child: Row(
        children: [
          const Gap(15),
          Expanded(
            child: text.isEmpty
                ? const LoadingLineContent(width: double.infinity)
                : BBText(
                    text,
                    style: context.font.bodyLarge,
                    color: context.colour.secondary,
                  ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            icon: Icon(
              Icons.copy_sharp,
              color: context.colour.secondary,
            ),
            onPressed: () {
              Clipboard.getData(Clipboard.kTextPlain).then(
                (value) {
                  if (value != null) {
                    onChanged(value.text ?? '');
                  }
                },
              );
            },
          ),
          const Gap(8),
        ],
      ),
    );
  }
}
