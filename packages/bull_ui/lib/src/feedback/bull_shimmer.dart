import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmering skeleton box — duplicated from `core/widgets/loading/loading_box_content.dart`.
class BullShimmerBox extends StatelessWidget {
  const BullShimmerBox({
    super.key,
    required this.height,
    this.width,
    this.padding,
  });

  /// Box height.
  final double height;

  /// Box width (defaults to full width).
  final double? width;

  /// Outer padding.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Shimmer.fromColors(
      baseColor: colors.shimmerBase,
      highlightColor: colors.shimmerHighlight,
      child: Padding(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          width: width ?? double.infinity,
          height: height,
          margin: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.0),
            color: colors.surface,
          ),
        ),
      ),
    );
  }
}

/// Shimmering skeleton line — duplicated from `core/widgets/loading/loading_line_content.dart`.
class BullShimmerLine extends StatelessWidget {
  const BullShimmerLine({
    super.key,
    this.width = double.infinity,
    this.height = 12.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
  });

  /// Line width.
  final double width;

  /// Line height.
  final double height;

  /// Outer padding.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Shimmer.fromColors(
      baseColor: colors.shimmerBase,
      highlightColor: colors.shimmerHighlight,
      child: Padding(
        padding: padding,
        child: Container(width: width, height: height, color: colors.surface),
      ),
    );
  }
}
