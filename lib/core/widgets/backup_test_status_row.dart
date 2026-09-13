import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

/// The shared presentation of a successfully tested backup and its date.
/// Callers supply evidence of a completed test, never an attempt/upload time.
class BackupTestStatusRow extends StatelessWidget {
  final String label;
  final DateTime? testedAt;

  const BackupTestStatusRow({
    super.key,
    required this.label,
    required this.testedAt,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: Text(label, style: context.font.bodyMedium)),
          const Gap(12),
          Text(
            testedAt != null
                ? context.loc.backupSettingsTested
                : context.loc.backupSettingsNotTested,
            style: context.font.bodyMedium?.copyWith(
              color: testedAt != null
                  ? context.appColors.success
                  : context.appColors.error,
            ),
          ),
        ],
      ),
      if (testedAt != null)
        Text(
          context.loc.backupSettingsTestedOn(
            _formatDateTime(context, testedAt!.toLocal()),
          ),
          style: context.font.bodySmall?.copyWith(
            color: context.appColors.onSurfaceVariant,
          ),
        ),
    ],
  );
}

String _formatDateTime(BuildContext context, DateTime value) {
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatFullDate(value)}, '
      '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
}
