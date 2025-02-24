import 'package:flutter/material.dart';

class ReceiveSegmentedButtons extends StatelessWidget {
  final Widget child;
  const ReceiveSegmentedButtons({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [Text('Receive Segmented Buttons'), child],
    );
  }
}
