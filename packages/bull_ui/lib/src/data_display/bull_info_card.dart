import 'dart:math' as math;

import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/src/layout/gap.dart';

/// A coloured info panel with a leading accent bar and info icon.
///
/// [tagColor] tints the accent bar, icon and title; [bgColor] is the fill.
/// Both are caller-supplied so the card can express any semantic colour.
class BullInfoCard extends StatelessWidget {
  const BullInfoCard({
    super.key,
    this.title,
    required this.description,
    required this.tagColor,
    required this.bgColor,
    this.onTap,
    this.boldDescription = false,
  });

  /// Optional bold title shown above the description.
  final String? title;

  /// The body text.
  final String description;

  /// Accent colour for the bar, icon and title.
  final Color tagColor;

  /// Card background fill.
  final Color bgColor;

  /// Optional tap callback.
  final void Function()? onTap;

  /// Renders the description in bold when true.
  final bool boldDescription;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final title = this.title;
    final card = Container(
      constraints: onTap == null
          ? null
          : const BoxConstraints(minWidth: 48, minHeight: 48),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(context.bullShapes.card),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 4, color: tagColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _IconAndText(
                    iconColor: tagColor,
                    title: title != null && title.isNotEmpty ? title : null,
                    titleStyle: context.bullType.body.copyWith(
                      color: tagColor,
                      fontWeight: FontWeight.w500,
                    ),
                    description: description,
                    descriptionStyle: context.bullType.body.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: boldDescription
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return onTap == null
        ? card
        : Semantics(
            button: true,
            label: title != null && title.isNotEmpty
                ? '$title\n$description'
                : description,
            onTap: onTap,
            excludeSemantics: true,
            child: InkWell(onTap: onTap, child: card),
          );
  }
}

/// The icon sits on the first line of text, the title when there is one,
/// whatever the card's height or the text scale.
class _IconAndText extends StatelessWidget {
  const _IconAndText({
    required this.iconColor,
    required this.title,
    required this.titleStyle,
    required this.description,
    required this.descriptionStyle,
  });

  static const double _iconSize = 24;

  final Color iconColor;
  final String? title;
  final TextStyle titleStyle;
  final String description;
  final TextStyle descriptionStyle;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final firstStyle = title == null ? descriptionStyle : titleStyle;
    final lineHeight = (TextPainter(
      text: TextSpan(text: 'A', style: firstStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout()).height;
    final rowHeight = math.max(lineHeight, _iconSize);
    final textInset = (rowHeight - lineHeight) / 2;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: rowHeight,
          child: Center(
            child: Icon(
              Icons.info_outline_rounded,
              size: _iconSize,
              color: iconColor,
            ),
          ),
        ),
        const Gap(12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: textInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Text(title, style: titleStyle),
                  const Gap(4),
                ],
                Text(description, style: descriptionStyle),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
