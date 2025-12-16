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
    return BBText(displayLabel, style: style, maxLines: 1, overflow: .ellipsis);
  }
}
