import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

class BackupTestStatusRow extends StatelessWidget {
  final String label;
  final DateTime? testedAt;
  final bool _comingSoon;
  final bool unknown;

  const BackupTestStatusRow({
    super.key,
    required this.label,
    required this.testedAt,
    this.unknown = false,
  }) : _comingSoon = false;

  const BackupTestStatusRow.comingSoon({super.key, required this.label})
    : testedAt = null,
      unknown = false,
      _comingSoon = true;

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
              _comingSoon
                  ? context.loc.vaultBackupComingSoon
                  : unknown
                  ? context.loc.coreScreensUnknown
                  : date == null
                  ? context.loc.backupSettingsNotTested
                  : context.loc.backupSettingsTested,
              style: context.font.bodyMedium?.copyWith(
                color: _comingSoon || unknown
                    ? context.appColors.onSurfaceVariant
                    : date == null
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
