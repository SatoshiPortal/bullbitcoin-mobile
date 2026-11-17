import 'package:auto_size_text/auto_size_text.dart';
import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:flutter/widgets.dart';

/// Text primitive — duplicated from `core/widgets/text/text.dart`.
///
/// When [maxLines] is set it auto-sizes to fit; otherwise it renders a plain
/// [Text]. (AutoSizeText needs a line bound to shrink meaningfully and
/// otherwise trips a Flutter semantics assertion inside constrained slots.)
///
/// Give it a [role] of the type scale or a legacy [style], not both; neither keeps the ambient `DefaultTextStyle`.
class BullText extends StatelessWidget {
  const BullText(
    this.text, {
    super.key,
    this.role,
    this.style,
    this.maxLines,
    this.color,
    this.fontWeight,
    this.textAlign,
    this.overflow,
  }) : assert(
         role == null || style == null,
         'Pass a role or a style, not both',
       );

  /// The string to render.
  final String text;

  /// When set, the text auto-sizes to fit this many lines.
  final int? maxLines;

  /// The role of the type scale, read from `context.bullType`.
  final BullTextRole? role;

  /// The base text style, typically a `context.bullType` role with explicit overrides.
  final TextStyle? style;

  /// Overrides the style colour.
  final Color? color;

  /// Overrides the style weight; the size always comes from the role.
  final FontWeight? fontWeight;

  /// Horizontal alignment.
  final TextAlign? textAlign;

  /// Overflow handling.
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final role = this.role;
    final base = role == null ? style : context.bullType.of(role);
    final effectiveStyle = base?.copyWith(color: color, fontWeight: fontWeight);

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
