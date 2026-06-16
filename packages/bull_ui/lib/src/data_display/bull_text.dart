import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/widgets.dart';

/// Text primitive — duplicated from `core/widgets/text/text.dart`.
///
/// When [maxLines] is set it auto-sizes to fit; otherwise it renders a plain
/// [Text]. (AutoSizeText needs a line bound to shrink meaningfully and
/// otherwise trips a Flutter semantics assertion inside constrained slots.)
class BullText extends StatelessWidget {
  const BullText(
    this.text, {
    super.key,
    required this.style,
    this.maxLines,
    this.color,
    this.textAlign,
    this.overflow,
  });

  /// The string to render.
  final String text;

  /// When set, the text auto-sizes to fit this many lines.
  final int? maxLines;

  /// The base text style (typically a [TextStyle] from `BullTextStyles`).
  final TextStyle? style;

  /// Overrides the style colour.
  final Color? color;

  /// Horizontal alignment.
  final TextAlign? textAlign;

  /// Overflow handling.
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style?.copyWith(color: color);

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
