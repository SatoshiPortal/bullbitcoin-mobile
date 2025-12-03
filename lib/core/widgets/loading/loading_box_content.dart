import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class LoadingBoxContent extends StatelessWidget {
  const LoadingBoxContent({
    super.key,
    required this.height,
    this.width,
    this.padding,
  });

  final double height;
  final double? width;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: context.appColors.shimmerBase,
      highlightColor: context.appColors.shimmerHighlight,
      child: Padding(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          children: [
            Container(
              width: width ?? double.infinity,
              height: height,
              margin: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.0),
                color: context.appColors.surface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
