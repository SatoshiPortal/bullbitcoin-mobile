import 'package:backup_storage/backup_storage.dart';
import 'package:bull_ui/bull_ui.dart';

import '../../generated/l10n/backup_metadata_localizations.dart';
import 'widgets/backup_metadata_widgets.dart';

String backupDestinationLabel(
  BackupMetadataLocalizations l10n,
  BackupDestination destination,
) => switch (destination) {
  BackupDestination.googleDrive => l10n.googleDrive,
  BackupDestination.iCloud => l10n.iCloud,
  BackupDestination.folder => l10n.customLocation,
};

class BackupMetadataIntroView extends StatelessWidget {
  final List<BackupDestination> destinations;

  /// Null until the user picks one: nothing is preselected.
  final BackupDestination? selected;
  final ValueChanged<BackupDestination> onSelect;
  final VoidCallback onBack;
  final VoidCallback? onContinue;

  /// Restores from an existing backup without turning anything on. Read only.
  final VoidCallback? onRestore;

  const BackupMetadataIntroView({
    super.key,
    required this.destinations,
    required this.selected,
    required this.onSelect,
    required this.onBack,
    required this.onContinue,
    this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = BackupMetadataLocalizations.of(context);
    final available = destinations.toSet();
    final chosen = selected;
    final provider = chosen == null
        ? null
        : backupDestinationLabel(l10n, chosen);
    return BackupPage(
      title: l10n.dataBackup,
      onBack: onBack,
      children: [
        Text(l10n.intro, style: context.bullType.body),
        const Gap(BullSpacing.lg),
        BackupSectionTitle(l10n.whatIsSaved),
        BackupPickerRow(
          icon: BullIcons.sell,
          title: l10n.labels,
          subtitle: l10n.labelsDescription,
        ),
        BackupPickerRow(
          icon: BullIcons.lockOpen,
          title: l10n.neverRecoveryPhrase,
          subtitle: l10n.physicalBackup,
        ),
        const Gap(BullSpacing.lg),
        BackupSectionTitle(l10n.whoCanRead),
        Text(
          provider == null || chosen == BackupDestination.folder
              ? l10n.privacy
              : '${l10n.privacy} ${l10n.privacyProvider(provider)}',
          style: context.bullType.body,
        ),
        const Gap(BullSpacing.lg),
        BackupSectionTitle(l10n.where),
        for (final destination in available)
          BackupPickerRow(
            icon: destination == BackupDestination.folder
                ? BullIcons.accountTree
                : BullIcons.arrowUpward,
            title: backupDestinationLabel(l10n, destination),
            subtitle: switch (destination) {
              BackupDestination.googleDrive => l10n.driveDescription,
              BackupDestination.iCloud => l10n.iCloudDescription,
              BackupDestination.folder => l10n.folderDescription,
            },
            selected: chosen == destination,
            onTap: () => onSelect(destination),
          ),
      ],
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BullButton.primary(
            label: l10n.continueAction,
            onPressed: chosen != null && available.contains(chosen)
                ? onContinue
                : null,
          ),
          if (onRestore case final restore?) ...[
            const Gap(BullSpacing.sm),
            BullButton.secondary(
              label: l10n.restoreFromBackup,
              onPressed: restore,
            ),
          ],
        ],
      ),
    );
  }
}

class BackupMetadataWalletRow {
  final String name;
  final String subtitle;
  final Color color;
  final bool included;
  final bool supported;
  final bool seedBackupVerified;
  final bool watchOnly;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onTestBackup;

  const BackupMetadataWalletRow({
    required this.name,
    required this.subtitle,
    required this.color,
    required this.included,
    this.supported = true,
    this.seedBackupVerified = true,
    this.watchOnly = false,
    this.onChanged,
    this.onTestBackup,
  });
}

class BackupMetadataWalletsView extends StatelessWidget {
  final List<BackupMetadataWalletRow> rows;
  final int unattributedLabelCount;
  final VoidCallback onBack;
  final VoidCallback? onTurnOn;

  const BackupMetadataWalletsView({
    super.key,
    required this.rows,
    required this.onBack,
    required this.onTurnOn,
    this.unattributedLabelCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = BackupMetadataLocalizations.of(context);
    return BackupPage(
      title: l10n.walletsTitle,
      onBack: onBack,
      children: [
        Text(l10n.walletsIntro, style: context.bullType.body),
        const Gap(BullSpacing.md),
        for (final row in rows)
          _WalletLine(
            color: row.color,
            title: row.name,
            subtitle: row.supported ? row.subtitle : l10n.unsupported,
            trailing: _WalletSwitch(
              label: l10n.backUpWallet(row.name),
              included: row.supported && row.included,
              onChanged: row.supported ? row.onChanged : null,
            ),
            details: [
              if (row.supported && row.watchOnly)
                BullInfoBar(
                  message: l10n.publicKeyWarning,
                  icon: BullIcons.warningAmber,
                  tone: BullInfoTone.warning,
                )
              else if (row.supported && !row.seedBackupVerified) ...[
                BullInfoBar(
                  message: l10n.unverified,
                  icon: BullIcons.warningAmber,
                  tone: BullInfoTone.warning,
                ),
                if (row.onTestBackup case final test?)
                  BackupInlineAction(label: l10n.testBackup, onTap: test),
              ],
            ],
          ),
        if (unattributedLabelCount > 0) ...[
          const Gap(BullSpacing.md),
          BullInfoBar(
            message: l10n.unattributedLabels(unattributedLabelCount),
            tone: BullInfoTone.warning,
            icon: BullIcons.warningAmber,
          ),
        ],
      ],
      footer: BullButton.primary(
        label: l10n.turnOn,
        onPressed: rows.any((row) => row.supported && row.included)
            ? onTurnOn
            : null,
      ),
    );
  }
}

class _WalletSwitch extends StatelessWidget {
  final String label;
  final bool included;
  final ValueChanged<bool>? onChanged;

  const _WalletSwitch({
    required this.label,
    required this.included,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    void toggle() => change?.call(!included);

    return Semantics(
      label: label,
      toggled: included,
      enabled: change != null,
      onTap: change == null ? null : toggle,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: change == null ? null : toggle,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: IgnorePointer(
                child: BullSwitch(value: included, onChanged: change),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum BackupMetadataStatus { upToDate, changesWaiting, actionNeeded }

class BackupMetadataGroupStatus {
  final Color color;
  final String name;
  final String detail;

  const BackupMetadataGroupStatus({
    required this.color,
    required this.name,
    required this.detail,
  });
}

class BackupMetadataStatusView extends StatelessWidget {
  final BackupMetadataStatus status;
  final String detail;
  final int changesWaiting;

  /// Notes left out because they looked like secrets: a count, never text.
  final int excluded;
  final List<BackupMetadataGroupStatus> groups;
  final int walletTotal;
  final BackupDestination destination;
  final VoidCallback onBack;
  final VoidCallback? onReconnect;
  final VoidCallback? onBackUpNow;
  final VoidCallback onWallets;
  final VoidCallback onDestination;
  final VoidCallback onRestore;
  final VoidCallback onTurnOff;

  const BackupMetadataStatusView({
    super.key,
    required this.status,
    required this.detail,
    required this.groups,
    required this.walletTotal,
    required this.destination,
    required this.onBack,
    this.onReconnect,
    this.onBackUpNow,
    required this.onWallets,
    required this.onDestination,
    required this.onRestore,
    required this.onTurnOff,
    this.changesWaiting = 0,
    this.excluded = 0,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = BackupMetadataLocalizations.of(context);
    final provider = backupDestinationLabel(l10n, destination);
    final needsAction = status == BackupMetadataStatus.actionNeeded;
    return BackupPage(
      title: l10n.dataBackup,
      onBack: onBack,
      children: [
        if (needsAction) ...[
          BackupSectionTitle(l10n.actionNeeded),
          BullInfoBar(
            message: detail,
            icon: BullIcons.warningAmber,
            tone: BullInfoTone.warning,
          ),
          const Gap(BullSpacing.sm),
          if (onReconnect case final reconnect?)
            BullButton.primary(
              label: l10n.reconnect(provider),
              onPressed: reconnect,
            ),
        ] else
          Row(
            children: [
              BullIcon(
                status == BackupMetadataStatus.upToDate
                    ? BullIcons.checkCircle
                    : BullIcons.sync,
                color: status == BackupMetadataStatus.upToDate
                    ? context.bull.success
                    : context.bull.textMuted,
              ),
              const Gap(BullSpacing.sm),
              Expanded(
                child: BackupRowText(
                  title: status == BackupMetadataStatus.upToDate
                      ? l10n.upToDate
                      : l10n.changesWaiting(changesWaiting),
                  subtitle: detail,
                ),
              ),
            ],
          ),
        if (excluded > 0) ...[
          const Gap(BullSpacing.md),
          BullInfoBar(
            message: l10n.excludedRecords(excluded),
            tone: BullInfoTone.warning,
            icon: BullIcons.warningAmber,
          ),
        ],
        const Gap(BullSpacing.lg),
        BackupSectionTitle(l10n.wallets),
        for (final group in groups)
          _WalletLine(
            color: group.color,
            title: group.name,
            subtitle: group.detail,
          ),
        const Gap(BullSpacing.md),
        BullButton.secondary(label: l10n.backUpNow, onPressed: onBackUpNow),
        const Gap(BullSpacing.lg),
        BackupSummaryEntry(
          icon: BullIcons.accountBalanceWallet,
          title: l10n.walletsTitle,
          summary: l10n.walletCount(groups.length, walletTotal),
          onTap: onWallets,
        ),
        BackupSummaryEntry(
          icon: BullIcons.arrowUpward,
          title: l10n.destination,
          summary: provider,
          onTap: onDestination,
        ),
        BullSettingsEntryItem(
          icon: BullIcons.history,
          title: l10n.restoreFromBackup,
          onTap: onRestore,
        ),
        BullSettingsEntryItem(
          icon: BullIcons.close,
          iconColor: context.bull.error,
          textColor: context.bull.error,
          title: l10n.turnOff,
          onTap: onTurnOff,
        ),
      ],
    );
  }
}

class _WalletLine extends StatelessWidget {
  final Color color;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final List<Widget> details;

  const _WalletLine({
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.details = const [],
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: context.bull.border)),
    ),
    padding: const EdgeInsets.symmetric(vertical: BullSpacing.sm),
    child: Row(
      children: [
        Container(width: 4, height: 32, color: color),
        const Gap(BullSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BackupRowText(title: title, subtitle: subtitle),
              for (final detail in details) ...[
                const Gap(BullSpacing.xs),
                detail,
              ],
            ],
          ),
        ),
        if (trailing case final action?) ...[const Gap(BullSpacing.sm), action],
      ],
    ),
  );
}
