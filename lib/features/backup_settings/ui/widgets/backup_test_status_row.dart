import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

class BackupTestStatusRow extends StatelessWidget {
  final String label;
  final DateTime? testedAt;

  const BackupTestStatusRow({
    super.key,
    required this.label,
    required this.testedAt,
  });

  @override
  Widget build(BuildContext context) {
    final date = testedAt?.toLocal();
    final localizations = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: context.font.bodyMedium)),
            const Gap(12),
            Text(
              date == null
                  ? context.loc.backupSettingsNotTested
                  : context.loc.backupSettingsTested,
              style: context.font.bodyMedium?.copyWith(
                color: date == null
                    ? context.appColors.error
                    : context.appColors.success,
              ),
            ),
          ],
        ),
        if (date != null)
          Text(
            context.loc.backupSettingsTestedOn(
              '${localizations.formatFullDate(date)}, ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date))}',
            ),
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
