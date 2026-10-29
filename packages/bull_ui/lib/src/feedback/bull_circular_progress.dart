import 'package:flutter/material.dart';
import '../theme/bull_theme.dart';

/// A small progress ring with theme colours and an optional accessible label.
class BullCircularProgress extends StatelessWidget {
  final double? value;
  final Color? color;
  final double size;
  final String? semanticsLabel;

  const BullCircularProgress({
    super.key,
    this.value,
    this.color,
    this.size = 16,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CircularProgressIndicator(
      value: value,
      strokeWidth: 2,
      color: color ?? context.bull.primary,
      backgroundColor: context.bull.surface,
      semanticsLabel: semanticsLabel,
    ),
  );
}
