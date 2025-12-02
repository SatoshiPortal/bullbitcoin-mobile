import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
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
    final borderColor = hasError
        ? context.appColors.error
        : context.appColors.onSecondaryFixed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.loc.dcaSelectFrequencyLabel,
          style: context.font.bodyMedium,
        ),
        Text(
          context.loc.dcaSelectFrequencyLabel,
          style: context.font.bodyMedium,
        ),
        const Gap(4),
        RadioGroup<DcaBuyFrequency>(
          groupValue: selectedFrequency,
          onChanged: onChanged ?? (_) {},
          child: Column(
            children: DcaBuyFrequency.values.map((frequency) {
              return Column(
                children: [
                  RadioListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: borderColor),
                    ),
                    title: Text(switch (frequency) {
                      DcaBuyFrequency.hourly =>
                        context.loc.dcaConfirmFrequencyHourly,
                      DcaBuyFrequency.daily =>
                        context.loc.dcaConfirmFrequencyDaily,
                      DcaBuyFrequency.weekly =>
                        context.loc.dcaConfirmFrequencyWeekly,
                      DcaBuyFrequency.monthly =>
                        context.loc.dcaConfirmFrequencyMonthly,
                    }, style: context.font.headlineSmall),
                    value: frequency,
                  ),
                  const Gap(16),
                ],
              );
            }).toList(),
          ),
        ),
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
