import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class LoadingBoxContent extends StatelessWidget {
  const LoadingBoxContent({super.key, required this.height, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: width ?? double.infinity,
              height: height,
              margin: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.0),
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
