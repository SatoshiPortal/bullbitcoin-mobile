import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/dropdown/bb_dropdown.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_schedule.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

final class BullVaultScheduleFields extends StatelessWidget {
  final BullVaultSchedule schedule;
  final bool usesTwoColdKeys;
  final bool includeInheritance;
  final ValueChanged<int> onColdChanged;
  final ValueChanged<int> onRecoveryChanged;
  final ValueChanged<int> onInheritanceChanged;

  const BullVaultScheduleFields({
    super.key,
    required this.schedule,
    required this.usesTwoColdKeys,
    required this.includeInheritance,
    required this.onColdChanged,
    required this.onRecoveryChanged,
    required this.onInheritanceChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (!usesTwoColdKeys || !includeInheritance) ...[
        _ScheduleDropdown(
          label: usesTwoColdKeys
              ? context.loc.bullVaultEitherColdDelay
              : context.loc.bullVaultColdDelay,
          value: schedule.coldDelay,
          values: [
            for (
              var delay = BullVaultSchedule.minDelay;
              delay <= BullVaultSchedule.maxDelay;
              delay++
            )
              if (includeInheritance
                  ? delay > schedule.recoveryDelay &&
                        delay < schedule.inheritanceDelay
                  : delay < schedule.recoveryDelay)
                delay,
          ],
          unit: schedule.unit,
          onChanged: onColdChanged,
        ),
        const Gap(12),
      ],
      _ScheduleDropdown(
        label: !includeInheritance
            ? context.loc.bullVaultEverydayDelay
            : context.loc.bullVaultRecoveryDelay,
        value: schedule.recoveryDelay,
        values: [
          for (
            var delay = BullVaultSchedule.minDelay;
            delay <= BullVaultSchedule.maxDelay;
            delay++
          )
            if (includeInheritance
                ? usesTwoColdKeys
                      ? delay < schedule.inheritanceDelay
                      : delay < schedule.coldDelay
                : delay > schedule.coldDelay)
              delay,
        ],
        unit: schedule.unit,
        onChanged: onRecoveryChanged,
      ),
      if (includeInheritance) ...[
        const Gap(12),
        _ScheduleDropdown(
          label: context.loc.bullVaultInheritanceDelay,
          value: schedule.inheritanceDelay,
          values: [
            for (
              var delay = BullVaultSchedule.minDelay;
              delay <= BullVaultSchedule.maxDelay;
              delay++
            )
              if (delay >
                  (usesTwoColdKeys
                      ? schedule.recoveryDelay
                      : schedule.coldDelay))
                delay,
          ],
          unit: schedule.unit,
          onChanged: onInheritanceChanged,
        ),
      ],
    ],
  );
}

final class _ScheduleDropdown extends StatelessWidget {
  final String label;
  final int value;
  final List<int> values;
  final BullVaultScheduleUnit unit;
  final ValueChanged<int> onChanged;

  const _ScheduleDropdown({
    required this.label,
    required this.value,
    required this.values,
    this.unit = BullVaultScheduleUnit.years,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: context.font.bodyMedium),
      const Gap(8),
      BBDropdown<int>(
        value: values.contains(value) ? value : null,
        items: [
          for (final delay in values)
            DropdownMenuItem(
              value: delay,
              child: Text(switch (unit) {
                BullVaultScheduleUnit.years => context.loc.bullVaultYears(
                  delay,
                ),
                BullVaultScheduleUnit.hours => context.loc.bullVaultHours(
                  delay,
                ),
              }),
            ),
        ],
        onChanged: (delay) {
          if (delay != null) onChanged(delay);
        },
      ),
    ],
  );
}
