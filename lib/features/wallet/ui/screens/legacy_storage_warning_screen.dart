import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/legacy_storage/legacy_storage_important_callout.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/legacy_storage/legacy_storage_screen_scaffold.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/legacy_storage/legacy_storage_step_row.dart';
import 'package:bull_ui/bull_ui.dart';

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
    final steps = <String>[
      loc.legacyStorageStepBackupWallet,
      loc.legacyStorageStepExportLabels,
      loc.legacyStorageStepEnsureSwapsCompleted,
      loc.legacyStorageStepUninstall,
      loc.legacyStorageStepReinstall,
      loc.legacyStorageStepRestoreBackup,
    ];

    return LegacyStorageScreenScaffold(
      badgeLabel: loc.legacyStorageBadgeActionRequired,
      title: hasNoBackup
          ? loc.legacyStorageNoBackupPageTitle
          : loc.legacyStorageHasBackupPageTitle,
      dotCount: hasNoBackup ? 2 : 1,
      dotIndex: 0,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BullText(
            loc.legacyStorageIntroDescription,
            style: context.bullText.bodyMedium?.copyWith(
              color: context.bull.onSurface,
              height: 1.35,
            ),
          ),
          const Gap(10),
          for (final (i, label) in steps.indexed)
            LegacyStorageStepRow(index: i + 1, label: label),
          const Gap(10),
          LegacyStorageImportantCallout(
            title: loc.legacyStorageImportantTitle,
            body: hasNoBackup
                ? loc.legacyStorageImportantBody
                : loc.legacyStorageHasBackupImportantBody,
          ),
          const Gap(10),
          BullText(
            hasNoBackup
                ? loc.legacyStorageContinueFooterNoBackup
                : loc.legacyStorageContinueFooterHasBackup,
            style: context.bullText.bodyMedium?.copyWith(
              color: context.bull.onSurface,
              height: 1.35,
            ),
          ),
        ],
      ),
      primaryButton: hasNoBackup
          ? BullButton.primary(
              label: loc.legacyStorageBackupNowButton,
              onPressed: onBackupNow,
            )
          : null,
      secondaryButton: BullButton.secondary(
        label: hasNoBackup
            ? loc.legacyStorageRiskAckButton
            : loc.legacyStorageRiskAckButtonHasBackup,
        onPressed: onAcknowledgeRisk,
      ),
    );
  }
}
