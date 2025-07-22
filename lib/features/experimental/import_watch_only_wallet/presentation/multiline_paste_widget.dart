import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

class MultilinePasteWidget extends StatelessWidget {
  final String title;
  final String value;
  final String hint;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final Function(String) onChanged;

  const MultilinePasteWidget({
    super.key,
    required this.title,
    required this.value,
    required this.hint,
    this.maxLines,
    this.minLines,
    this.maxLength,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BBText(title, style: context.font.titleMedium),
        const Gap(16),
        Stack(
          children: [
            BBInputText(
              onChanged: onChanged,
              value: value,
              hint: hint,
              maxLines: maxLines,
              minLines: minLines,
              maxLength: maxLength,
            ),
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) onChanged(data!.text!);
                  },
                  icon: Icon(Icons.copy, color: context.colour.primary),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
