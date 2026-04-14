import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

class BBText extends StatelessWidget {
  const BBText(
    this.text, {
    super.key,
    required this.style,
    this.maxLines,
    this.color,
    this.textAlign,
    this.overflow,
  });

  final String text;
  final int? maxLines;
  final TextStyle? style;
  final Color? color;
  final TextAlign? textAlign;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style?.copyWith(color: color);

    // AutoSizeText requires a maxLines bound to meaningfully shrink text.
    // Without it, the widget still runs its multi-pass layout algorithm, which
    // triggers a `!semantics.parentDataDirty` Flutter assertion when placed
    // inside constrained Material slots such as ListTile.title/subtitle or
    // CheckboxListTile.title.  Fall back to plain Text in that case — behaviour
    // is identical since there is no line count to fit into.
    if (maxLines == null) {
      return Text(
        text,
        style: effectiveStyle,
        textAlign: textAlign,
        softWrap: true,
        overflow: overflow,
      );
    }

    return AutoSizeText(
      text,
      style: effectiveStyle,
      maxLines: maxLines,
      textAlign: textAlign,
      softWrap: true,
      overflow: overflow,
    );
  }
}
