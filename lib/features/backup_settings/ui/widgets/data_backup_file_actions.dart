import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/data_backup_file_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/data_backup_file_screen.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DataBackupFileActions extends StatelessWidget {
  final void Function(WalletBackupSnapshot, WalletBackupRecovery) onRecovered;
  const DataBackupFileActions({super.key, required this.onRecovered});

  Future<void> _exportReadable(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.loc.dataBackupReadableWarning),
        content: Text(context.loc.dataBackupReadableBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.loc.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.loc.continueButton),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<DataBackupFileCubit>().export(
        WalletBackupFileFormat.readable,
        confirmed: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<DataBackupFileCubit, DataBackupFileState>(
        listenWhen: (a, b) =>
            a.comparison != b.comparison ||
            a.exported != b.exported ||
            a.failure != b.failure,
        listener: (context, state) async {
          if (!state.busy &&
              state.comparison != null &&
              state.result == null &&
              state.failure == null) {
            final cubit = context.read<DataBackupFileCubit>();
            await Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: cubit,
                  child: DataBackupFileScreen(onRecovered: onRecovered),
                ),
              ),
            );
            if (!cubit.isClosed) cubit.reset();
          } else if (state.exported) {
            SnackBarUtils.showSnackBar(
              context,
              context.loc.dataBackupFileExported,
            );
          } else if (state.failure != null && state.comparison == null) {
            SnackBarUtils.showSnackBar(
              context,
              state.failure!.toTranslated(context),
            );
          }
        },
        builder: (context, state) => Column(
          children: [
            SettingsEntryItem(
              icon: Icons.lock_outline,
              title: context.loc.dataBackupExportEncrypted,
              onTap: state.busy
                  ? null
                  : () => context.read<DataBackupFileCubit>().export(
                      WalletBackupFileFormat.encrypted,
                    ),
            ),
            SettingsEntryItem(
              icon: Icons.no_encryption_outlined,
              title: context.loc.dataBackupExportReadable,
              onTap: state.busy ? null : () => _exportReadable(context),
            ),
            SettingsEntryItem(
              icon: Icons.file_open_outlined,
              title: context.loc.dataBackupImportFile,
              onTap: state.busy
                  ? null
                  : context.read<DataBackupFileCubit>().inspect,
            ),
            if (state.busy) const LinearProgressIndicator(),
          ],
        ),
      );
}
