import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/dropdown/bb_dropdown.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

final class BullVaultScheduleDropdown extends StatelessWidget {
  final String label;
  final int value;
  final List<int> values;
  final ValueChanged<int> onChanged;

  const BullVaultScheduleDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.values,
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
          for (final year in values)
            DropdownMenuItem(
              value: year,
              child: Text(context.loc.bullVaultYears(year)),
            ),
        ],
        onChanged: (year) {
          if (year != null) onChanged(year);
        },
      ),
    ],
  );
}
