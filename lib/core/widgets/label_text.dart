import 'package:bb_mobile/core/labels/domain/label.dart';
import 'package:bb_mobile/core/labels/label_system.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';

class LabelText extends StatelessWidget {
  const LabelText(this.label, {super.key, this.style});

  final Label label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    String displayLabel = label.label;
    if (LabelSystem.isSystemLabel(label.label)) {
      displayLabel = LabelSystem.fromLabel(
        label.label,
      ).toTranslatedLabel(context);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: displayLabel, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        final isOverflowing = textPainter.didExceedMaxLines;

        final textWidget = BBText(
          displayLabel,
          style: style,
          maxLines: 1,
          overflow: .ellipsis,
        );

        if (isOverflowing) {
          return Tooltip(message: displayLabel, child: textWidget);
        }

        return textWidget;
      },
    );
  }
}
