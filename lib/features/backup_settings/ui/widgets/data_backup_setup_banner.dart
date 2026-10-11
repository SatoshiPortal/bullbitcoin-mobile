import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/data_backup_setup_cubit.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class DataBackupSetupBanner extends StatelessWidget {
  const DataBackupSetupBanner({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<DataBackupSetupCubit, DataBackupSetupState>(
        builder: (context, state) {
          final incomplete = state.control?.recoveryIncomplete == true;
          if (!state.loading && !incomplete && state.failure == null) {
            return const SizedBox.shrink();
          }
          return Card(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ListTile(
              leading: state.loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_off_outlined),
              title: Text(
                state.loading
                    ? context.loc.dataBackupSettingUp
                    : incomplete
                    ? context.loc.dataBackupRecoveryIncomplete
                    : context.loc.dataBackupSetupFailed,
              ),
              subtitle: state.failure == null
                  ? null
                  : Text(state.failure!.toTranslated(context)),
              onTap: state.loading
                  ? null
                  : () =>
                        context.pushNamed<void>(SettingsRoute.dataBackup.name),
              trailing: state.failure == null
                  ? null
                  : TextButton(
                      onPressed: () =>
                          context.read<DataBackupSetupCubit>().retry(),
                      child: Text(context.loc.retry),
                    ),
            ),
          );
        },
      );
}
