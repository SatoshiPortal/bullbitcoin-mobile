import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/dca/domain/dca.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class DcaFrequencyRadioList extends StatelessWidget {
  const DcaFrequencyRadioList({
    super.key,
    this.selectedFrequency,
    this.onChanged,
    this.errorText,
  });

  final DcaBuyFrequency? selectedFrequency;
  final ValueChanged<DcaBuyFrequency?>? onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;
    final borderColor =
        hasError ? context.colour.error : context.colour.onSecondaryFixed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Select Frequency', style: context.font.bodyMedium),
        const Gap(4),
        ...DcaBuyFrequency.values.map((frequency) {
          return Column(
            children: [
              RadioListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: borderColor),
                ),
                title: Text(switch (frequency) {
                  DcaBuyFrequency.hourly => 'Every hour',
                  DcaBuyFrequency.daily => 'Every day',
                  DcaBuyFrequency.weekly => 'Every week',
                  DcaBuyFrequency.monthly => 'Every month',
                }, style: context.font.headlineSmall),
                value: frequency,
                groupValue: selectedFrequency,
                onChanged: onChanged,
              ),
              const Gap(16),
            ],
          );
        }),
        if (hasError) ...[
          const Gap(4),
          Text(
            errorText!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
