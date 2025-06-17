import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class LoadingLineContent extends StatelessWidget {
  const LoadingLineContent({
    super.key,
    this.width = double.infinity,
    this.height = 12.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
  });

  final double width;
  final double height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: width, height: height, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
