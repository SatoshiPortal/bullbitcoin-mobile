import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/backup_settings/domain/data_backup_status.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/data_backup_settings_cubit.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullSwitch, Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DataBackupSettingsScreen extends StatefulWidget {
  final Future<void> Function(bool server) onContents;
  final Future<void> Function() onWords;
  final Future<void> Function() onRecovery;
  final Future<void> Function() onRecoverWords;
  final Widget fileActions;
  final Widget dataExports;
  const DataBackupSettingsScreen({
    super.key,
    required this.onContents,
    required this.onWords,
    required this.onRecovery,
    required this.onRecoverWords,
    required this.fileActions,
    required this.dataExports,
  });

  @override
  State<DataBackupSettingsScreen> createState() =>
      _DataBackupSettingsScreenState();
}

class _DataBackupSettingsScreenState extends State<DataBackupSettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<DataBackupSettingsCubit>().refresh(retryPublication: true);
    }
  }

  Future<void> _open(Future<void> Function() action) async {
    await action();
    if (mounted) {
      await context.read<DataBackupSettingsCubit>().refresh(
        retryPublication: true,
      );
    }
  }

  Future<void> _enable(bool enabled) async {
    if (enabled) {
      final answer = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.loc.dataBackupConsentTitle),
          content: Text(context.loc.dataBackupConsentBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.loc.cancelButton),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.loc.dataBackupEnable),
            ),
          ],
        ),
      );
      if (answer != true || !mounted) return;
    }
    if (mounted) {
      await context.read<DataBackupSettingsCubit>().setEnabled(enabled);
    }
  }

  Future<void> _delete() async {
    final cubit = context.read<DataBackupSettingsCubit>();
    if (cubit.state.data?.control.enabled == true) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.loc.dataBackupDelete),
          content: Text(context.loc.dataBackupDeleteRequiresDisabled),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.loc.okButton),
            ),
          ],
        ),
      );
      return;
    }
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.loc.dataBackupDelete),
        content: Text(context.loc.dataBackupDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.loc.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.loc.dataBackupDelete),
          ),
        ],
      ),
    );
    if (answer == true && mounted) await cubit.delete(confirmed: true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loc.dataBackupTitle)),
    body: SafeArea(
      child: BlocBuilder<DataBackupSettingsCubit, DataBackupSettingsState>(
        builder: (context, state) {
          final data = state.data;
          final failure =
              state.failure ??
              state.readFailure ??
              (data?.publishing == true ? null : data?.failure);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(context.loc.dataBackupPublicContentsExplanation),
              const Gap(24),
              if (state.loading || state.working)
                const LinearProgressIndicator(),
              if (data != null) ...[
                Row(
                  children: [
                    Expanded(child: Text(context.loc.dataBackupAutomatic)),
                    BullSwitch(
                      key: const ValueKey('data-backup-enabled'),
                      value: data.control.enabled == true,
                      onChanged: state.working && data.control.enabled != true
                          ? null
                          : _enable,
                    ),
                  ],
                ),
                Text(_status(context, data)),
                if (data.lastSuccessAt case final date?)
                  Text(
                    '${context.loc.dataBackupLastSuccess}: ${MaterialLocalizations.of(context).formatMediumDate(date.toLocal())}',
                  ),
                const Gap(16),
                if (data.control.enabled == true &&
                    !data.control.recoveryIncomplete)
                  BullButton.big(
                    key: const ValueKey('data-backup-now'),
                    label: context.loc.dataBackupNow,
                    disabled: state.working || data.publishing,
                    bgColor: context.appColors.primary,
                    textColor: context.appColors.onPrimary,
                    onPressed: context.read<DataBackupSettingsCubit>().publish,
                  ),
                if (data.control.recoveryIncomplete)
                  SettingsEntryItem(
                    icon: Icons.restore,
                    title: context.loc.dataBackupFinishRecovery,
                    onTap: state.working
                        ? null
                        : () => _open(widget.onRecovery),
                  ),
              ],
              if (failure != null) ...[
                const Gap(16),
                Text(failure.toTranslated(context)),
              ],
              if (failure != null || data == null)
                TextButton(
                  onPressed: state.loading || state.working
                      ? null
                      : () => context.read<DataBackupSettingsCubit>().refresh(
                          retryPublication: true,
                        ),
                  child: Text(context.loc.retry),
                ),
              if (state.deleted) Text(context.loc.dataBackupDeleted),
              const Gap(24),
              SettingsEntryItem(
                icon: Icons.list_alt,
                title: context.loc.dataBackupContentsTitle,
                onTap: state.working
                    ? null
                    : () => _open(() => widget.onContents(false)),
              ),
              SettingsEntryItem(
                icon: Icons.cloud_download_outlined,
                title: context.loc.dataBackupCheckServer,
                onTap: state.working
                    ? null
                    : () => _open(() => widget.onContents(true)),
              ),
              SettingsEntryItem(
                icon: Icons.password_outlined,
                title: context.loc.dataBackupWordsTitle,
                onTap: state.working ? null : () => _open(widget.onWords),
              ),
              SettingsEntryItem(
                icon: Icons.restore,
                title: context.loc.dataBackupRecoverWithWords,
                onTap: state.working
                    ? null
                    : () => _open(widget.onRecoverWords),
              ),
              const Gap(24),
              Text(
                context.loc.dataBackupFilesTitle,
                style: context.font.titleMedium,
              ),
              widget.fileActions,
              const Gap(24),
              widget.dataExports,
              const Gap(24),
              SettingsEntryItem(
                key: const ValueKey('data-backup-delete'),
                icon: Icons.delete_outline,
                title: context.loc.dataBackupDelete,
                iconColor: context.appColors.error,
                textColor: context.appColors.error,
                onTap: state.working || data == null ? null : _delete,
              ),
            ],
          );
        },
      ),
    ),
  );

  String _status(BuildContext context, DataBackupStatus data) {
    if (data.control.recoveryIncomplete) {
      return context.loc.dataBackupRecoveryIncomplete;
    }
    if (data.control.enabled == null) return context.loc.dataBackupUndecided;
    if (data.control.enabled == false) return context.loc.dataBackupOff;
    if (data.publishing) return context.loc.dataBackupInProgress;
    if (data.failure != null) return '';
    if (data.isUpToDate) return context.loc.dataBackupSucceeded;
    return context.loc.dataBackupPending;
  }
}
