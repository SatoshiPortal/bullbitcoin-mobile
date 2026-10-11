import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullDropdown, BullSpacing, Gap;
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/data_backup_contents_cubit.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/data_backup_settings_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/data_backup_contents.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DataBackupContentsScreen extends StatelessWidget {
  final Future<void> Function(WalletBackupInspection) onRecover;
  const DataBackupContentsScreen({super.key, required this.onRecover});

  Future<void> _replace(
    BuildContext context,
    WalletBackupInspection inspection,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.loc.dataBackupReplace),
        content: Text(context.loc.dataBackupReplaceBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.loc.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.loc.dataBackupReplace),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final settings = context.read<DataBackupSettingsCubit>();
    await settings.publish(replace: inspection, confirmed: true);
    if (context.mounted && settings.state.failure == null) {
      await context.read<DataBackupContentsCubit>().load(server: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loc.dataBackupContentsTitle)),
    body: SafeArea(
      child: BlocBuilder<DataBackupContentsCubit, DataBackupContentsState>(
        builder: (context, state) {
          final settings = context.watch<DataBackupSettingsCubit>().state;
          final busy = state.loading || settings.working;
          return ListView(
            padding: const EdgeInsets.all(BullSpacing.lg),
            children: [
              BullDropdown<bool>(
                value: state.server,
                height: null,
                items: [
                  DropdownMenuItem(
                    value: false,
                    child: Text(context.loc.dataBackupSourceLocal),
                  ),
                  DropdownMenuItem(
                    value: true,
                    child: Text(context.loc.dataBackupSourceServer),
                  ),
                ],
                onChanged: settings.working
                    ? null
                    : (server) {
                        if (server != null) {
                          context.read<DataBackupContentsCubit>().load(
                            server: server,
                          );
                        }
                      },
              ),
              const Gap(BullSpacing.lg),
              if (state.loading) const LinearProgressIndicator(),
              if (state.failure case final failure?)
                Text(failure.toTranslated(context)),
              if (settings.failure case final failure?)
                Text(failure.toTranslated(context)),
              if (state.snapshot case final snapshot?)
                DataBackupContents(
                  snapshot: snapshot,
                  source: state.server
                      ? DataBackupContentsSource.server
                      : DataBackupContentsSource.local,
                )
              else if (state.inspection != null && !state.loading)
                Text(context.loc.dataBackupMissing),
              const Gap(BullSpacing.lg),
              TextButton(
                onPressed: busy
                    ? null
                    : () => context.read<DataBackupContentsCubit>().load(
                        server: state.server,
                      ),
                child: Text(
                  state.failure == null
                      ? context.loc.vaultBackupCheckAgain
                      : context.loc.retry,
                ),
              ),
              if (state.inspection case final inspection?) ...[
                if (inspection.snapshot != null)
                  BullButton.big(
                    maxLines: null,
                    disabled: busy,
                    onPressed: () => onRecover(inspection),
                    label: context.loc.dataBackupRecover,
                    bgColor: context.appColors.primary,
                    textColor: context.appColors.onPrimary,
                  ),
                if (settings.data?.control.enabled == true &&
                    settings.data?.control.recoveryIncomplete != true)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => _replace(context, inspection),
                    child: Text(context.loc.dataBackupReplace),
                  ),
              ],
            ],
          );
        },
      ),
    ),
  );
}
