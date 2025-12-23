import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';

class UseForFeeEstimationToggle extends StatelessWidget {
  final bool useForFeeEstimation;
  final bool isProcessing;
  final Function(bool) onChanged;

  const UseForFeeEstimationToggle({
    super.key,
    required this.useForFeeEstimation,
    required this.isProcessing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.loc.mempoolSettingsUseForFeeEstimation,
                        style: context.font.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.loc.mempoolSettingsUseForFeeEstimationDescription,
                        style: context.font.bodySmall?.copyWith(
                          color: context.appColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: useForFeeEstimation,
                  onChanged: isProcessing ? null : onChanged,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
