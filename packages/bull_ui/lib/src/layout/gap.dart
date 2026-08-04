// Vendored from the `gap` package (https://pub.dev/packages/gap), v3.0.1.
//
// Copyright (c) 2020 Romain Rastel. Licensed under the MIT License.
//
// Reimplemented here so the design system owns its spacing primitive and the
// app no longer depends on the external `gap` package. Only `Gap` is vendored
// (the package's `MaxGap`/`SliverGap` are unused in this project). Behaviour is
// identical to upstream: a fixed main-axis gap that reads its enclosing Flex
// direction at layout time (with a `Scrollable` fallback). Constructors were
// modernised to super-parameters to satisfy bull_ui's lint set; the layout and
// paint logic is unchanged from upstream.

// RenderGap takes public named parameters (e.g. `mainAxisExtent`) backed by
// private fields with custom setters that call markNeedsLayout/Paint. An
// initializing formal would require a private named parameter, which Dart
// disallows, so the initializer-list assignment is intentional here.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A widget that takes a fixed amount of space in the direction of its parent.
///
/// It only works in the following cases:
/// - It is a descendant of a [Row], [Column], or [Flex], and the path from the
///   [Gap] widget to its enclosing [Row], [Column], or [Flex] contains only
///   [StatelessWidget]s or [StatefulWidget]s (not [RenderObjectWidget]s).
/// - It is a descendant of a [Scrollable].
class Gap extends StatelessWidget {
  /// Creates a widget that takes a fixed [mainAxisExtent] of space in the
  /// direction of its parent.
  const Gap(this.mainAxisExtent, {super.key, this.crossAxisExtent, this.color})
    : assert(mainAxisExtent >= 0 && mainAxisExtent < double.infinity),
      assert(crossAxisExtent == null || crossAxisExtent >= 0);

  /// Creates a widget that takes a fixed [mainAxisExtent] of space in the
  /// direction of its parent and expands in the cross axis direction.
  const Gap.expand(double mainAxisExtent, {Key? key, Color? color})
    : this(
        mainAxisExtent,
        key: key,
        crossAxisExtent: double.infinity,
        color: color,
      );

  /// The amount of space this widget takes in the direction of its parent.
  ///
  /// If the parent is a [Column] this is the height; if a [Row], the width.
  final double mainAxisExtent;

  /// The amount of space this widget takes in the opposite direction of the
  /// parent. Null (the default) means it matches the parent's cross-axis
  /// constraint.
  final double? crossAxisExtent;

  /// The color used to fill the gap.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scrollableState = Scrollable.maybeOf(context);
    final axisDirection = scrollableState?.axisDirection;
    final fallbackDirection = axisDirection == null
        ? null
        : axisDirectionToAxis(axisDirection);

    return _RawGap(
      mainAxisExtent,
      crossAxisExtent: crossAxisExtent,
      color: color,
      fallbackDirection: fallbackDirection,
    );
  }
}

class _RawGap extends LeafRenderObjectWidget {
  const _RawGap(
    this.mainAxisExtent, {
    this.crossAxisExtent,
    this.color,
    this.fallbackDirection,
  }) : assert(mainAxisExtent >= 0 && mainAxisExtent < double.infinity),
       assert(crossAxisExtent == null || crossAxisExtent >= 0);

  final double mainAxisExtent;
  final double? crossAxisExtent;
  final Color? color;
  final Axis? fallbackDirection;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderGap(
      mainAxisExtent: mainAxisExtent,
      crossAxisExtent: crossAxisExtent ?? 0,
      color: color,
      fallbackDirection: fallbackDirection,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderGap renderObject) {
    renderObject
      ..mainAxisExtent = mainAxisExtent
      ..crossAxisExtent = crossAxisExtent ?? 0
      ..color = color
      ..fallbackDirection = fallbackDirection;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('mainAxisExtent', mainAxisExtent));
    properties.add(
      DoubleProperty('crossAxisExtent', crossAxisExtent, defaultValue: 0),
    );
    properties.add(ColorProperty('color', color));
    properties.add(EnumProperty<Axis>('fallbackDirection', fallbackDirection));
  }
}

/// Render object backing [Gap]. Sizes itself along the enclosing [RenderFlex]'s
/// direction (or [fallbackDirection] when inside a [Scrollable]).
class RenderGap extends RenderBox {
  RenderGap({
    required double mainAxisExtent,
    double? crossAxisExtent,
    Axis? fallbackDirection,
    Color? color,
  }) : _mainAxisExtent = mainAxisExtent,
       _crossAxisExtent = crossAxisExtent,
       _color = color,
       _fallbackDirection = fallbackDirection;

  double get mainAxisExtent => _mainAxisExtent;
  double _mainAxisExtent;
  set mainAxisExtent(double value) {
    if (_mainAxisExtent != value) {
      _mainAxisExtent = value;
      markNeedsLayout();
    }
  }

  double? get crossAxisExtent => _crossAxisExtent;
  double? _crossAxisExtent;
  set crossAxisExtent(double? value) {
    if (_crossAxisExtent != value) {
      _crossAxisExtent = value;
      markNeedsLayout();
    }
  }

  Axis? get fallbackDirection => _fallbackDirection;
  Axis? _fallbackDirection;
  set fallbackDirection(Axis? value) {
    if (_fallbackDirection != value) {
      _fallbackDirection = value;
      markNeedsLayout();
    }
  }

  Axis? get _direction {
    final parentNode = parent;
    if (parentNode is RenderFlex) {
      return parentNode.direction;
    } else {
      return fallbackDirection;
    }
  }

  Color? get color => _color;
  Color? _color;
  set color(Color? value) {
    if (_color != value) {
      _color = value;
      markNeedsPaint();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    return _computeIntrinsicExtent(
      Axis.horizontal,
      () => super.computeMinIntrinsicWidth(height),
    )!;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    return _computeIntrinsicExtent(
      Axis.horizontal,
      () => super.computeMaxIntrinsicWidth(height),
    )!;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return _computeIntrinsicExtent(
      Axis.vertical,
      () => super.computeMinIntrinsicHeight(width),
    )!;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return _computeIntrinsicExtent(
      Axis.vertical,
      () => super.computeMaxIntrinsicHeight(width),
    )!;
  }

  double? _computeIntrinsicExtent(Axis axis, double Function() compute) {
    final direction = _direction;
    if (direction == axis) {
      return _mainAxisExtent;
    } else {
      if (_crossAxisExtent!.isFinite) {
        return _crossAxisExtent;
      } else {
        return compute();
      }
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final direction = _direction;

    if (direction != null) {
      if (direction == Axis.horizontal) {
        return constraints.constrain(Size(mainAxisExtent, crossAxisExtent!));
      } else {
        return constraints.constrain(Size(crossAxisExtent!, mainAxisExtent));
      }
    } else {
      throw FlutterError(
        'A Gap widget must be placed directly inside a Flex widget '
        'or its fallbackDirection must not be null',
      );
    }
  }

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (color != null) {
      final paint = Paint()..color = color!;
      context.canvas.drawRect(offset & size, paint);
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('mainAxisExtent', mainAxisExtent));
    properties.add(DoubleProperty('crossAxisExtent', crossAxisExtent));
    properties.add(ColorProperty('color', color));
    properties.add(EnumProperty<Axis>('fallbackDirection', fallbackDirection));
  }
}
