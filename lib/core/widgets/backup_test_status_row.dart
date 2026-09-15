import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

/// The shared presentation of a successfully tested backup and its date.
/// Callers supply evidence of a completed test, never an attempt/upload time.
class BackupTestStatusRow extends StatelessWidget {
  final String label;
  final DateTime? testedAt;

  /// What the most recent attempt did, when it produced no date of its own.
  ///
  /// It sits beside [testedAt] rather than replacing it: a failed check says
  /// nothing about the backup an earlier check proved was there.
  final String? latestAttempt;

  /// A destination the app cannot use yet: neutral, never tested or untested.
  final bool unavailable;

  /// A state of its own instead of a test verdict, shown neutral: a search
  /// still running, or a destination nobody has chosen yet.
  final String? state;

  const BackupTestStatusRow({
    super.key,
    required this.label,
    required this.testedAt,
    this.latestAttempt,
  }) : unavailable = false,
       state = null;

  const BackupTestStatusRow.unavailable({super.key, required this.label})
    : testedAt = null,
      latestAttempt = null,
      unavailable = true,
      state = null;

  const BackupTestStatusRow.state({
    super.key,
    required this.label,
    required String this.state,
  }) : testedAt = null,
       latestAttempt = null,
       unavailable = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: Text(label, style: context.font.bodyMedium)),
          const Gap(12),
          Text(
            state ??
                (unavailable
                    ? context.loc.backupSettingsComingSoon
                    : testedAt != null
                    ? context.loc.backupSettingsTested
                    : context.loc.backupSettingsNotTested),
            style: context.font.bodyMedium?.copyWith(
              color: state != null || unavailable
                  ? context.appColors.onSurfaceVariant
                  : testedAt != null
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
      if (latestAttempt != null)
        Text(
          latestAttempt!,
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
