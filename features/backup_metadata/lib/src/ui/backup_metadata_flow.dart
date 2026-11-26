import 'package:backup_storage/backup_storage.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:labels/backup.dart';
import 'package:material_ui/material_ui.dart'
    show CircularProgressIndicator, StatefulBuilder, showDialog;

import '../../generated/l10n/backup_metadata_localizations.dart';
import '../domain/backup_metadata_failure.dart';
import '../domain/entities/backup_status.dart';
import '../domain/entities/discovered_backup.dart';
import '../presentation/backup_metadata_failure_l10n.dart';
import '../presentation/backup_metadata_restore_cubit.dart';
import '../presentation/backup_metadata_settings_cubit.dart';
import 'backup_metadata_restore_views.dart';
import 'backup_metadata_views.dart';
import 'widgets/backup_metadata_widgets.dart';

enum _Step { intro, wallets, status, restore }

/// The whole data backup journey: turn on, status, restore, turn off.
///
/// It talks only to the two cubits of the member and renders the member's
/// own views, so every control is named, localized and reachable through the
/// semantics tree.
class BackupMetadataFlow extends StatefulWidget {
  final BackupMetadataSettingsCubit settings;
  final BackupMetadataRestoreCubit restore;
  final List<BackupDestination> destinations;
  final VoidCallback onClose;

  const BackupMetadataFlow({
    super.key,
    required this.settings,
    required this.restore,
    required this.destinations,
    required this.onClose,
  });

  @override
  State<BackupMetadataFlow> createState() => _BackupMetadataFlowState();
}

class _BackupMetadataFlowState extends State<BackupMetadataFlow> {
  _Step? _step;
  late BackupDestination _selected = widget.destinations.first;
  Set<String> _chosen = {};

  @override
  void initState() {
    super.initState();
    widget.settings.refresh();
  }

  BackupRunStatus? _statusOf(BackupMetadataSettingsState state) =>
      switch (state) {
        BackupMetadataSettingsReady(:final status) => status,
        BackupMetadataSettingsLoading(:final previous) => previous,
        BackupMetadataSettingsFailed(:final previous) => previous,
        BackupMetadataSettingsInitial() => null,
      };

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<
      BackupMetadataSettingsCubit,
      BackupMetadataSettingsState
    >(
      bloc: widget.settings,
      listenWhen: (_, current) => current is BackupMetadataSettingsReady,
      listener: (context, state) {
        if (state is BackupMetadataSettingsReady && _step == null) {
          final destination = state.status.destination;
          setState(() {
            _step = destination == null ? _Step.intro : _Step.status;
            if (destination != null) _selected = destination;
          });
        }
      },
      builder: (context, state) {
        final status = _statusOf(state);
        final step = _step;
        if (status == null || step == null) {
          return _Waiting(
            failure: state is BackupMetadataSettingsFailed
                ? state.failure
                : null,
            onBack: widget.onClose,
          );
        }
        return switch (step) {
          _Step.intro => BackupMetadataIntroView(
            destinations: widget.destinations,
            selected: _selected,
            onSelect: (destination) => setState(() => _selected = destination),
            onBack: status.destination == null
                ? widget.onClose
                : () => setState(() => _step = _Step.status),
            onContinue: () => setState(() => _step = _Step.wallets),
          ),
          _Step.wallets => _wallets(context, status),
          _Step.status => _statusView(context, status),
          _Step.restore => _restore(context, status),
        };
      },
    );
  }

  // ---------------------------------------------------------------- wallets

  Widget _wallets(BuildContext context, BackupRunStatus status) {
    final l10n = BackupMetadataLocalizations.of(context);
    final included = {
      for (final group in status.groups)
        if (group.included) group.group.id,
    };
    final chosen = _chosen.isEmpty && included.isNotEmpty ? included : _chosen;
    return BackupMetadataWalletsView(
      rows: [
        for (final entry in status.groups)
          BackupMetadataWalletRow(
            name: entry.group.displayName,
            subtitle: l10n.labelCount(entry.group.bitcoinWalletIds.length),
            color: chosen.contains(entry.group.id)
                ? context.bull.primary
                : context.bull.textMuted,
            included: chosen.contains(entry.group.id),
            seedBackupVerified: entry.group.seedBackupVerified,
            watchOnly: entry.group.isWatchOnly,
            onChanged: (value) => setState(() {
              _chosen = {...chosen};
              value
                  ? _chosen.add(entry.group.id)
                  : _chosen.remove(entry.group.id);
            }),
          ),
        for (final wallet in status.unsupported)
          BackupMetadataWalletRow(
            name: wallet.walletId,
            subtitle: l10n.unsupported,
            color: context.bull.textMuted,
            included: false,
            supported: false,
          ),
      ],
      unattributedLabelCount: status.unattributedCount,
      onBack: () => setState(
        () => _step = status.destination == null ? _Step.intro : _Step.status,
      ),
      onTurnOn: chosen.isEmpty
          ? null
          : () async {
              await widget.settings.configure(
                destination: _selected,
                groups: chosen,
              );
              await widget.settings.backupNow();
              if (mounted) setState(() => _step = _Step.status);
            },
    );
  }

  // ----------------------------------------------------------------- status

  Widget _statusView(BuildContext context, BackupRunStatus status) {
    final l10n = BackupMetadataLocalizations.of(context);
    final destination = status.destination ?? _selected;
    final provider = backupDestinationLabel(l10n, destination);
    final groups = [
      for (final group in status.groups)
        if (group.included) group,
    ];
    final needsAction = groups.any(
      (group) => group.failure != null || group.actionNeeded != null,
    );
    final waiting = groups.where((group) => group.pendingChanges).length;
    final latest = groups
        .map((group) => group.lastDurableBackup)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    final date = latest == null
        ? ''
        : DateFormat.yMMMd(Localizations.localeOf(context).toString())
              .add_jm()
              .format(latest.toLocal());
    final failure = groups
        .map((group) => group.failure)
        .whereType<BackupMetadataFailure>()
        .firstOrNull;
    final detail = needsAction
        ? (failure?.toTranslated(context) ??
              l10n.reconnectStatus(provider, waiting))
        : waiting > 0
        ? l10n.pendingStatus(date)
        : l10n.recentStatus(date);
    return BackupMetadataStatusView(
      status: needsAction
          ? BackupMetadataStatus.actionNeeded
          : waiting > 0
          ? BackupMetadataStatus.changesWaiting
          : BackupMetadataStatus.upToDate,
      detail: detail,
      changesWaiting: waiting,
      groups: [
        for (final group in groups)
          BackupMetadataGroupStatus(
            color: group.failure == null
                ? context.bull.success
                : context.bull.warning,
            name: group.group.displayName,
            detail: group.lastDurableBackup == null
                ? l10n.off
                : group.previousVersionKept
                ? l10n.previousVersionKept(l10n.latestVersion(date))
                : l10n.latestVersion(date),
          ),
      ],
      walletTotal: status.groups.length,
      destination: destination,
      onBack: widget.onClose,
      onReconnect: needsAction
          ? () => widget.settings.configure(
              destination: destination,
              groups: {for (final group in groups) group.group.id},
            )
          : null,
      onBackUpNow: widget.settings.backupNow,
      onWallets: () => setState(() {
        _chosen = {for (final group in groups) group.group.id};
        _step = _Step.wallets;
      }),
      onDestination: () => setState(() => _step = _Step.intro),
      onRestore: () {
        widget.restore.discover(destination);
        setState(() => _step = _Step.restore);
      },
      onTurnOff: () => _turnOff(context),
    );
  }

  Future<void> _turnOff(BuildContext context) async {
    var deleteBackups = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, setDialog) => BackupMetadataTurnOffDialog(
          deleteBackups: deleteBackups,
          onDeleteBackupsChanged: (value) =>
              setDialog(() => deleteBackups = value),
          onCancel: () => Navigator.of(dialog).pop(false),
          onTurnOff: () => Navigator.of(dialog).pop(true),
        ),
      ),
    );
    if (confirmed != true) return;
    await widget.settings.configure(
      destination: null,
      groups: const {},
      deleteOwnedFiles: deleteBackups,
    );
    if (mounted) setState(() => _step = _Step.intro);
  }

  // ---------------------------------------------------------------- restore

  Widget _restore(BuildContext context, BackupRunStatus status) {
    final l10n = BackupMetadataLocalizations.of(context);
    return BlocBuilder<BackupMetadataRestoreCubit, BackupMetadataRestoreState>(
      bloc: widget.restore,
      builder: (context, state) {
        void back() => setState(() => _step = _Step.status);
        return switch (state) {
          BackupMetadataRestoreInitial() ||
          BackupMetadataRestoreLoading() => _Waiting(onBack: back),
          BackupMetadataRestoreFailed(:final failure) => _Waiting(
            failure: failure,
            onBack: back,
          ),
          BackupMetadataRestoreDiscovered(:final backups) =>
            backups.isEmpty
                ? _Waiting(message: l10n.nothingDeleted, onBack: back)
                : _Picker(
                    backups: backups,
                    onPick: widget.restore.preview,
                    onBack: back,
                  ),
          BackupMetadataRestorePreview(
            :final backup,
            :final plan,
            :final choices,
          ) =>
            BackupMetadataRestorePreviewView(
              groupName: backup.group.displayName,
              destination: backup.destination,
              versions: [
                BackupMetadataVersionRow(
                  title: l10n.latestVersion(_date(context, backup.storedAt)),
                  selected: true,
                  onSelect: () {},
                ),
              ],
              differences: [
                for (final conflict in plan.conflicts)
                  BackupMetadataDifference(
                    title: conflict.ref,
                    localLabel: conflict.localLabel,
                    backupLabel: conflict.incomingLabel,
                    choice:
                        choices.resolutions[conflict] ??
                        ConflictResolution.keepLocal,
                    onChoose: (resolution) =>
                        widget.restore.choose(conflict, resolution),
                  ),
              ],
              labelsToAdd: plan.additions.length,
              coinsToFreeze: plan.freezes.length,
              alreadySame: plan.unchanged,
              onBack: back,
              onRestore: widget.restore.apply,
            ),
          BackupMetadataRestoreReported(:final report) =>
            BackupMetadataRestoreResultView(
              labelsRestored: report.labels?.labelsApplied ?? 0,
              coinsFrozen:
                  report.labels?.freezes.values
                      .where((outcome) => outcome == FreezeOutcome.applied)
                      .length ??
                  0,
              coinsPending:
                  report.labels?.freezes.values
                      .where(
                        (outcome) => outcome == FreezeOutcome.pendingDiscovery,
                      )
                      .length ??
                  0,
              coinsFailed:
                  (report.labels?.freezes.values
                          .where(
                            (outcome) =>
                                outcome == FreezeOutcome.failed ||
                                outcome == FreezeOutcome.notOwned,
                          )
                          .length ??
                      0) +
                  (report.isPartial ? 1 : 0),
              labelsRejected:
                  report.labels?.labelsRejected.values.fold<int>(
                    0,
                    (a, b) => a + b,
                  ) ??
                  0,
              onDone: back,
              onRetryFreezes: report.isPartial ? widget.restore.apply : null,
            ),
        };
      },
    );
  }

  String _date(BuildContext context, DateTime? value) => value == null
      ? ''
      : DateFormat.yMMMd(Localizations.localeOf(context).toString())
            .format(value.toLocal());
}

class _Waiting extends StatelessWidget {
  final BackupMetadataFailure? failure;
  final String? message;
  final VoidCallback onBack;

  const _Waiting({this.failure, this.message, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final l10n = BackupMetadataLocalizations.of(context);
    final text = message ?? failure?.toTranslated(context);
    return BackupPage(
      title: l10n.dataBackup,
      onBack: onBack,
      children: [
        if (text == null)
          const Center(child: CircularProgressIndicator())
        else
          Text(text, style: context.bullType.body),
      ],
    );
  }
}

class _Picker extends StatelessWidget {
  final List<DiscoveredBackup> backups;
  final ValueChanged<DiscoveredBackup> onPick;
  final VoidCallback onBack;

  const _Picker({
    required this.backups,
    required this.onPick,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = BackupMetadataLocalizations.of(context);
    return BackupPage(
      title: l10n.restoreFromBackup,
      onBack: onBack,
      children: [
        for (final backup in backups)
          BackupPickerRow(
            icon: BullIcons.history,
            title: backup.group.displayName,
            subtitle: l10n.foundIn(
              backupDestinationLabel(l10n, backup.destination),
            ),
            onTap: () => onPick(backup),
          ),
      ],
    );
  }
}
