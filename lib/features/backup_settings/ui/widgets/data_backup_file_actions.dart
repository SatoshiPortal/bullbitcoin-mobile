import 'package:bull_ui/bull_ui.dart'
    show BullSettingsEntryItem, BullSpacing, Gap;
import 'package:bb_mobile/core/utils/build_context_x.dart';
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
        listenWhen: (previous, current) => switch (current) {
          DataBackupFilePreview() => previous is! DataBackupFilePreview,
          _ => true,
        },
        listener: (context, state) async {
          switch (state) {
            case DataBackupFilePreview():
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
            case DataBackupFileExported():
              SnackBarUtils.showSnackBar(
                context,
                context.loc.dataBackupFileExported,
              );
            case DataBackupFileFailed(:final failure):
              SnackBarUtils.showSnackBar(
                context,
                failure.toTranslated(context),
              );
            case DataBackupFileInitial() || DataBackupFileWorking():
              break;
          }
        },
        builder: (context, state) => Column(
          children: [
            BullSettingsEntryItem(
              titleMaxLines: null,
              icon: Icons.lock_outline,
              title: context.loc.dataBackupExportEncrypted,
              onTap: state.busy
                  ? null
                  : () => context.read<DataBackupFileCubit>().export(
                      WalletBackupFileFormat.encrypted,
                    ),
            ),
            BullSettingsEntryItem(
              titleMaxLines: null,
              icon: Icons.no_encryption_outlined,
              title: context.loc.dataBackupExportReadable,
              onTap: state.busy ? null : () => _exportReadable(context),
            ),
            BullSettingsEntryItem(
              titleMaxLines: null,
              icon: Icons.file_open_outlined,
              title: context.loc.dataBackupImportFile,
              onTap: state.busy
                  ? null
                  : context.read<DataBackupFileCubit>().inspect,
            ),
            if (state.busy) ...[
              const Gap(BullSpacing.md),
              const LinearProgressIndicator(),
              const Gap(BullSpacing.md),
              Text(context.loc.dataBackupPreparingFile),
            ],
          ],
        ),
      );
}
