import 'package:flutter/widgets.dart';

/// A [Column] that becomes scrollable when its content overflows but still
/// fills the viewport when it fits — duplicated from
/// `core/widgets/scrollable_column.dart`.
///
/// Follows the Flutter team's recommended `SingleChildScrollView` +
/// `ConstrainedBox(minHeight)` + `IntrinsicHeight` pattern so `Spacer`s and
/// bottom-pinned children behave inside a scroll view.
class BullScrollableColumn extends StatelessWidget {
  const BullScrollableColumn({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.textBaseline,
    this.spacing = 0.0,
    this.children = const <Widget>[],
  });

  /// Outer padding around the scrollable content.
  final EdgeInsetsGeometry padding;

  /// Forwarded to the inner [Column].
  final MainAxisAlignment mainAxisAlignment;

  /// Forwarded to the inner [Column].
  final MainAxisSize mainAxisSize;

  /// Forwarded to the inner [Column].
  final CrossAxisAlignment crossAxisAlignment;

  /// Forwarded to the inner [Column].
  final TextDirection? textDirection;

  /// Forwarded to the inner [Column].
  final VerticalDirection verticalDirection;

  /// Forwarded to the inner [Column].
  final TextBaseline? textBaseline;

  /// Forwarded to the inner [Column].
  final double spacing;

  /// The column children.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, viewportConstraints) {
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: viewportConstraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: mainAxisAlignment,
                mainAxisSize: mainAxisSize,
                crossAxisAlignment: crossAxisAlignment,
                textDirection: textDirection,
                verticalDirection: verticalDirection,
                textBaseline: textBaseline,
                spacing: spacing,
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }
}
