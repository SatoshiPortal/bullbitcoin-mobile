import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class LoadingLineContent extends StatelessWidget {
  const LoadingLineContent({
    super.key,
    required this.width,
  });

  final double width;

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
              width: double.infinity,
              height: 12.0,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
