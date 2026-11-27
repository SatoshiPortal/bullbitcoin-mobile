import 'package:labels/backup.dart';
import 'package:backup_storage/backup_storage.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:intl/intl.dart';

import '../../generated/l10n/backup_metadata_localizations.dart';
import 'backup_metadata_views.dart';
import 'widgets/backup_metadata_widgets.dart';

/// Confirms the provider, the account and the wallets before anything is sent.
class BackupMetadataConfirmDialog extends StatelessWidget {
  final BackupDestination destination;

  /// As the storage names the account; shown here and nowhere else.
  final String? account;
  final List<String> wallets;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const BackupMetadataConfirmDialog({
    super.key,
    required this.destination,
    required this.account,
    required this.wallets,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = BackupMetadataLocalizations.of(context);
    final provider = backupDestinationLabel(l10n, destination);
    return BullDialog(
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              namesRoute: true,
              header: true,
              child: Text(l10n.confirmTitle, style: context.bullType.subtitle),
            ),
            const Gap(BullSpacing.md),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.confirmMessage(provider),
                      style: context.bullType.body,
                    ),
                    const Gap(BullSpacing.sm),
                    Text(
                      l10n.confirmAccount(account ?? l10n.unknownAccount),
                      style: context.bullType.body,
                    ),
                    const Gap(BullSpacing.sm),
                    for (final wallet in wallets)
                      Text('• $wallet', style: context.bullType.body),
                  ],
                ),
              ),
            ),
            const Gap(BullSpacing.md),
            Row(
              children: [
                Expanded(
                  child: BullButton.secondary(
                    label: l10n.cancel,
                    onPressed: onCancel,
                  ),
                ),
                const Gap(BullSpacing.sm),
                Expanded(
                  child: BullButton.primary(
                    label: l10n.confirmAction,
                    onPressed: onConfirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BackupMetadataTurnOffDialog extends StatelessWidget {
  final bool deleteBackups;
  final ValueChanged<bool> onDeleteBackupsChanged;
  final VoidCallback onCancel;
  final VoidCallback? onTurnOff;

  const BackupMetadataTurnOffDialog({
    super.key,
    required this.deleteBackups,
    required this.onDeleteBackupsChanged,
    required this.onCancel,
    required this.onTurnOff,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = BackupMetadataLocalizations.of(context);
    return BullDialog(
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              namesRoute: true,
              header: true,
              child: Text(l10n.turnOffTitle, style: context.bullType.subtitle),
            ),
            const Gap(BullSpacing.md),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.turnOffMessage, style: context.bullType.body),
                    const Gap(BullSpacing.sm),
                    Semantics(
                      label: l10n.alsoDelete,
                      checked: deleteBackups,
                      onTap: () => onDeleteBackupsChanged(!deleteBackups),
                      child: ExcludeSemantics(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onDeleteBackupsChanged(!deleteBackups),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Row(
                              children: [
                                BullCheckbox(
                                  checked: deleteBackups,
                                  onChanged: null,
                                ),
                                Flexible(
                                  child: Text(
                                    l10n.alsoDelete,
                                    style: context.bullType.body,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Gap(BullSpacing.md),
            Row(
              children: [
                Expanded(
                  child: BullButton.secondary(
                    label: l10n.cancel,
                    onPressed: onCancel,
                  ),
                ),
                const Gap(BullSpacing.sm),
                Expanded(
                  child: BullButton.primary(
                    label: l10n.turnOff,
                    onPressed: onTurnOff,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BackupMetadataRestorePromptSheet extends StatelessWidget {
  final VoidCallback? onLookInDrive;
  final VoidCallback? onLookInICloud;
  final VoidCallback onChooseFile;
  final VoidCallback onNotNow;

  const BackupMetadataRestorePromptSheet({
    super.key,
    this.onLookInDrive,
    this.onLookInICloud,
    required this.onChooseFile,
    required this.onNotNow,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = BackupMetadataLocalizations.of(context);
    return BullBottomSheet(
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BullSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                namesRoute: true,
                child: BullTopBar(
                  title: l10n.restorePrompt,
                  onAction: onNotNow,
                ),
              ),
              const Gap(BullSpacing.md),
              Text(l10n.restorePromptMessage, style: context.bullType.body),
              const Gap(BullSpacing.md),
              if (onLookInDrive case final lookInDrive?) ...[
                BullButton.primary(
                  label: l10n.lookInDrive,
                  onPressed: lookInDrive,
                ),
                const Gap(BullSpacing.sm),
              ],
              if (onLookInICloud case final lookInICloud?) ...[
                BullButton.secondary(
                  label: l10n.lookInICloud,
                  onPressed: lookInICloud,
                ),
                const Gap(BullSpacing.sm),
              ],
              if (onLookInDrive == null)
                BullButton.primary(
                  label: l10n.chooseFile,
                  onPressed: onChooseFile,
                )
              else
                BullButton.secondary(
                  label: l10n.chooseFile,
                  onPressed: onChooseFile,
                ),
              const Gap(BullSpacing.sm),
              Center(
                child: BackupInlineAction(label: l10n.notNow, onTap: onNotNow),
              ),
              Text(
                l10n.restoreLater,
                textAlign: TextAlign.center,
                style: context.bullType.label.copyWith(
                  color: context.bull.textMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BackupMetadataVersionRow {
  final String title;
  final bool selected;
  final VoidCallback onSelect;

  const BackupMetadataVersionRow({
    required this.title,
    required this.selected,
    required this.onSelect,
  });
}

class BackupMetadataDifference {
  final String title;
  final String localLabel;
  final String backupLabel;
  final ConflictResolution choice;
  final ValueChanged<ConflictResolution> onChoose;

  const BackupMetadataDifference({
    required this.title,
    required this.localLabel,
    required this.backupLabel,
    required this.onChoose,
    this.choice = ConflictResolution.keepLocal,
  });
}

class BackupMetadataRestorePreviewView extends StatelessWidget {
  final String groupName;
  final BackupDestination destination;
  final List<BackupMetadataVersionRow> versions;
  final List<BackupMetadataDifference> differences;
  final int labelsToAdd;
  final int coinsToFreeze;
  final int alreadySame;
  final int filteredFields;
  final VoidCallback onBack;
  final VoidCallback? onRestore;

  const BackupMetadataRestorePreviewView({
    super.key,
    required this.groupName,
    required this.destination,
    required this.versions,
    required this.differences,
    required this.labelsToAdd,
    required this.coinsToFreeze,
    required this.alreadySame,
    this.filteredFields = 0,
    required this.onBack,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = BackupMetadataLocalizations.of(context);
    return BackupPage(
      title: l10n.restoreLabels,
      onBack: onBack,
      children: [
        BackupRowText(
          title: groupName,
          subtitle: l10n.foundIn(backupDestinationLabel(l10n, destination)),
        ),
        if (versions.isNotEmpty) ...[
          const Gap(BullSpacing.md),
          BackupSectionTitle(l10n.version),
          for (final version in versions)
            BackupPickerRow(
              title: version.title,
              selected: versions.length > 1 && version.selected,
              onTap: versions.length > 1 ? version.onSelect : null,
            ),
        ],
        const Gap(BullSpacing.md),
        BackupSectionTitle(l10n.changesTitle),
        _ChangeCount(title: l10n.labelsToAdd, count: labelsToAdd),
        _ChangeCount(title: l10n.coinsToFreeze, count: coinsToFreeze),
        _ChangeCount(title: l10n.alreadySame, count: alreadySame),
        _ChangeCount(title: l10n.different, count: differences.length),
        if (filteredFields > 0) ...[
          const Gap(BullSpacing.md),
          BullInfoBar(
            message: l10n.restoreFilteredFields(filteredFields),
            tone: BullInfoTone.warning,
            icon: BullIcons.warningAmber,
          ),
        ],
        for (final difference in differences) ...[
          const Gap(BullSpacing.md),
          BackupSectionTitle(difference.title),
          BackupPickerRow(
            title: l10n.keepLabel(difference.localLabel),
            selected: difference.choice == ConflictResolution.keepLocal,
            onTap: () => difference.onChoose(ConflictResolution.keepLocal),
          ),
          BackupPickerRow(
            title: l10n.useBackupLabel(difference.backupLabel),
            selected: difference.choice == ConflictResolution.useBackup,
            onTap: () => difference.onChoose(ConflictResolution.useBackup),
          ),
        ],
      ],
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.nothingDeleted,
            textAlign: TextAlign.center,
            style: context.bullType.label.copyWith(
              color: context.bull.textMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
          const Gap(BullSpacing.xs),
          BullButton.primary(label: l10n.restore, onPressed: onRestore),
        ],
      ),
    );
  }
}

class _ChangeCount extends StatelessWidget {
  final String title;
  final int count;

  const _ChangeCount({required this.title, required this.count});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: BullSpacing.xxs),
    child: Row(
      children: [
        Expanded(child: Text(title, style: context.bullType.body)),
        Text(
          NumberFormat.decimalPattern(
            Localizations.localeOf(context).toLanguageTag(),
          ).format(count),
          style: context.bullType.body,
        ),
      ],
    ),
  );
}

class BackupMetadataRestoreResultView extends StatelessWidget {
  final int labelsRestored;
  final int coinsFrozen;
  final int coinsPending;
  final int coinsFailed;
  final int labelsRejected;
  final int differencesResolved;

  /// Wallet details attached and BIP85 children added: what Secrets wrote.
  final int walletsRestored;
  final int registryAdded;

  /// The Labels step as a whole failed; its counters are then unknown.
  final bool labelsStepFailed;

  /// The Secrets step as a whole failed.
  final bool secretsFailed;

  /// The BIP85 list conflicted with this phone's and was not restored.
  final bool registryRefused;

  /// Fields of the file ignored because they looked like secrets.
  final int excluded;
  final VoidCallback onDone;
  final VoidCallback? onEnableBackup;

  /// Runs the restore again, writing only what is still missing.
  final VoidCallback? onRetry;

  const BackupMetadataRestoreResultView({
    super.key,
    required this.labelsRestored,
    required this.coinsFrozen,
    required this.onDone,
    this.coinsPending = 0,
    this.coinsFailed = 0,
    this.labelsRejected = 0,
    this.differencesResolved = 0,
    this.walletsRestored = 0,
    this.registryAdded = 0,
    this.labelsStepFailed = false,
    this.secretsFailed = false,
    this.registryRefused = false,
    this.excluded = 0,
    this.onEnableBackup,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = BackupMetadataLocalizations.of(context);
    final stepFailed = labelsStepFailed || secretsFailed || registryRefused;
    final freezesOpen = coinsPending > 0 || coinsFailed > 0;
    final incomplete =
        labelsRejected > 0 || freezesOpen || stepFailed || excluded > 0;
    return BullSuccessScreen(
      title: l10n.restoreLabels,
      headline: incomplete ? l10n.restorePartial : l10n.labelsRestored,
      onClose: onDone,
      icon: incomplete
          ? BullIcon(
              BullIcons.warningAmber,
              size: 64,
              color: context.bull.warning,
            )
          : null,
      amountLine: coinsPending > 0 && coinsFrozen == 0
          ? l10n.pendingAmounts(labelsRestored, coinsPending)
          : l10n.restoredAmounts(labelsRestored, coinsFrozen),
      message:
          incomplete ||
              differencesResolved > 0 ||
              walletsRestored > 0 ||
              registryAdded > 0 ||
              excluded > 0
          ? Column(
              children: [
                if (differencesResolved > 0)
                  Text(l10n.differencesResolved(differencesResolved)),
                if (walletsRestored > 0)
                  Text(l10n.walletsRestored(walletsRestored)),
                if (registryAdded > 0)
                  Text(l10n.registryRestored(registryAdded)),
                if (secretsFailed) _warning(l10n.restoreSecretsFailed),
                if (registryRefused) _warning(l10n.restoreRegistryRefused),
                if (labelsStepFailed) _warning(l10n.restoreLabelsFailed),
                if (excluded > 0)
                  _warning(l10n.restoreFilteredFields(excluded)),
                if (labelsRejected > 0)
                  _warning(l10n.labelsRejected(labelsRejected)),
                if (coinsPending > 0)
                  _warning(l10n.freezePending(coinsPending)),
                if (coinsFailed > 0) _warning(l10n.freezeFailed(coinsFailed)),
              ],
            )
          : null,
      actions: [
        // A generic label whenever a step other than the freezes is open: the
        // retry then reruns the whole restore, not only the freezes.
        if (onRetry case final retry? when stepFailed || freezesOpen) ...[
          BullButton.secondary(
            label: stepFailed ? l10n.retryRestore : l10n.retryFreezes,
            onPressed: retry,
          ),
          const Gap(BullSpacing.sm),
        ],
        if (onEnableBackup case final enable?) ...[
          BullButton.secondary(
            label: l10n.enableAfterRestore,
            onPressed: enable,
          ),
          const Gap(BullSpacing.sm),
        ],
        BullButton.primary(label: l10n.done, onPressed: onDone),
      ],
    );
  }

  static Widget _warning(String message) => BullInfoBar(
    message: message,
    tone: BullInfoTone.warning,
    icon: BullIcons.warningAmber,
  );
}
