import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/get_paid_settings/presentation/get_paid_settings_cubit.dart';
import 'package:bb_mobile/features/get_paid_settings/presentation/get_paid_settings_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class GetPaidSettingsScreen extends StatelessWidget {
  const GetPaidSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.getPaidSettingsScreenTitle)),
      body: BlocBuilder<GetPaidSettingsCubit, GetPaidSettingsState>(
        builder: (context, state) {
          final settings = state.settings;
          final controlsEnabled = settings != null && !state.busy;
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            children: [
              if (state.status == GetPaidSettingsStatus.loading &&
                  settings == null)
                const LinearProgressIndicator(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.loc.getPaidAutomatedBackupToggleLabel),
                subtitle: Text(context.loc.getPaidBullnymBackupDisclosure),
                value: settings?.automatedBackupEnabled ?? false,
                onChanged: controlsEnabled
                    ? context.read<GetPaidSettingsCubit>().toggleAutomatedBackup
                    : null,
              ),
              const SizedBox(height: 8),
              _BackupStatus(state: state),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: controlsEnabled && settings.automatedBackupEnabled
                    ? context.read<GetPaidSettingsCubit>().backupNow
                    : null,
                icon: state.backingUp
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(context.loc.getPaidBackupNow),
              ),
              if (settings != null && !settings.automatedBackupEnabled) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: controlsEnabled
                      ? () => _confirmDelete(context)
                      : null,
                  icon: state.deleting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  label: Text(context.loc.getPaidDeleteBackup),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.loc.getPaidDeleteBackupTitle),
        content: Text(context.loc.getPaidDeleteBackupBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.loc.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<GetPaidSettingsCubit>().deleteRemoteBackup();
    }
  }
}

final class _BackupStatus extends StatelessWidget {
  final GetPaidSettingsState state;

  const _BackupStatus({required this.state});

  @override
  Widget build(BuildContext context) {
    final settings = state.settings;
    final String? text;
    if (settings == null) {
      text = null;
    } else if (settings.unsupportedVersion != null) {
      text = context.loc.getPaidBackupNeedsUpdate;
    } else if (settings.backupPending) {
      text = context.loc.getPaidBackupPending;
    } else if (settings.lastBackedUpAt != null) {
      text = context.loc.getPaidBackupLastSucceeded(
        _formatTimestamp(context, settings.lastBackedUpAt!),
      );
    } else {
      text = context.loc.getPaidBackupNever;
    }
    final error = state.status == GetPaidSettingsStatus.failure;
    return Semantics(
      liveRegion: true,
      child: Text(
        error ? context.loc.getPaidBackupError : text ?? '',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: error ? Theme.of(context).colorScheme.error : null,
        ),
      ),
    );
  }

  String _formatTimestamp(BuildContext context, int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(
      timestamp * 1000,
      isUtc: true,
    ).toLocal();
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatMediumDate(dateTime)} '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(dateTime))}';
  }
}
