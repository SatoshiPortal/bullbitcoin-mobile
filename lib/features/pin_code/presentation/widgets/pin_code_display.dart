import 'package:flutter/material.dart';

class PinCodeDisplay extends StatelessWidget {
  final String pinCode;
  final int maxPinCodeLength;
  final double? pinNumberRadius;

  const PinCodeDisplay({
    super.key,
    this.pinCode = "",
    this.maxPinCodeLength = 8,
    this.pinNumberRadius = 6,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          maxPinCodeLength,
          (index) {
            if (index < pinCode.length) {
              return CircleAvatar(
                backgroundColor: theme.primaryColor,
                radius: pinNumberRadius,
              );
            } else {
              return CircleAvatar(
                backgroundColor: theme.primaryColor.withValues(
                  alpha: 0.3,
                ),
                radius: pinNumberRadius,
              );
            }
          },
        ),
      ),
    );
  }
}
