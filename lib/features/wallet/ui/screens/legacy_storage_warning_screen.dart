import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/legacy_storage/legacy_storage_important_callout.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/legacy_storage/legacy_storage_screen_scaffold.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/legacy_storage/legacy_storage_step_row.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class LegacyStorageWarningScreen extends StatelessWidget {
  const LegacyStorageWarningScreen({
    super.key,
    required this.hasNoBackup,
    required this.onBackupNow,
    required this.onAcknowledgeRisk,
  });

  final bool hasNoBackup;
  final VoidCallback onBackupNow;
  final VoidCallback onAcknowledgeRisk;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final steps = <({String label, bool done})>[
      (label: loc.legacyStorageStepBackupWallet, done: !hasNoBackup),
      (label: loc.legacyStorageStepExportLabels, done: false),
      (label: loc.legacyStorageStepEnsureSwapsCompleted, done: false),
      (label: loc.legacyStorageStepUninstall, done: false),
      (label: loc.legacyStorageStepReinstall, done: false),
      (label: loc.legacyStorageStepRestoreBackup, done: false),
    ];

    return LegacyStorageScreenScaffold(
      badgeLabel: loc.legacyStorageBadgeActionRequired,
      title: hasNoBackup
          ? loc.legacyStorageNoBackupPageTitle
          : loc.legacyStorageHasBackupPageTitle,
      dotIndex: 0,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loc.legacyStorageIntroDescription,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.onSurface,
              height: 1.35,
            ),
          ),
          const Gap(10),
          for (final (i, step) in steps.indexed)
            LegacyStorageStepRow(
              index: i + 1,
              label: step.label,
              done: step.done,
            ),
          const Gap(10),
          LegacyStorageImportantCallout(
            title: loc.legacyStorageImportantTitle,
            body: loc.legacyStorageImportantBody,
          ),
          const Gap(10),
          Text(
            hasNoBackup
                ? loc.legacyStorageContinueFooterNoBackup
                : loc.legacyStorageContinueFooterHasBackup,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.onSurface,
              height: 1.35,
            ),
          ),
        ],
      ),
      primaryButton: BBButton.big(
        label: loc.legacyStorageBackupNowButton,
        onPressed: onBackupNow,
        bgColor: context.appColors.primary,
        textColor: context.appColors.onPrimary,
      ),
      secondaryButton: BBButton.big(
        label: loc.legacyStorageRiskAckButton,
        onPressed: onAcknowledgeRisk,
        bgColor: context.appColors.surface,
        textColor: context.appColors.primary,
        borderColor: context.appColors.primary,
        outlined: true,
      ),
    );
  }
}
