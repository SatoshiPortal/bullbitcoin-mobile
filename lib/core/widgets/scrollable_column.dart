import 'package:flutter/material.dart';

// As recommended here by the Flutter team:
// https://api.flutter.dev/flutter/widgets/SingleChildScrollView-class.html
class ScrollableColumn extends StatelessWidget {
  const ScrollableColumn({
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

  final EdgeInsetsGeometry padding;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final TextBaseline? textBaseline;
  final double spacing;
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
