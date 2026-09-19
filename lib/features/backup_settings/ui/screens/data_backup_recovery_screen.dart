import 'package:bb_mobile/features/backup_settings/ui/widgets/data_backup_recovery_result.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/data_backup_recovery_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/data_backup_contents.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Full recovery for the current wallet, after an explicit check/restore action.
class DataBackupRecoveryScreen extends StatelessWidget {
  final void Function(WalletBackupInspection, WalletBackupRecovery) onRecovered;
  final bool enableAfterRecovery;
  const DataBackupRecoveryScreen({
    super.key,
    required this.onRecovered,
    this.enableAfterRecovery = false,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loc.dataBackupTitle)),
    body: SafeArea(
      child: BlocConsumer<DataBackupRecoveryCubit, DataBackupRecoveryState>(
        listener: (_, state) {
          if (state case DataBackupRecoveryPreview(
            :final inspection,
            result: final result?,
          ) when result.complete) {
            onRecovered(inspection, result);
          }
        },
        builder: (context, state) => switch (state) {
          DataBackupRecoveryInitial() => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.busy) const LinearProgressIndicator(),
                if (state.failure case final failure?)
                  Text(failure.toTranslated(context)),
                if (!state.busy)
                  TextButton(
                    onPressed: () =>
                        context.read<DataBackupRecoveryCubit>().inspect(),
                    child: Text(
                      state.failure == null
                          ? context.loc.dataBackupInspect
                          : context.loc.retry,
                    ),
                  ),
              ],
            ),
          ),
          DataBackupRecoveryPreview() => Column(
            children: [
              if (state.busy) const LinearProgressIndicator(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (state.result case final result?)
                      DataBackupRecoveryResult(result: result),
                    if (state.failure case final failure?
                        when state.result == null ||
                            failure is! BackupSettingsRecoveryIncompleteFailure)
                      Text(failure.toTranslated(context)),
                    if (state.inspection.snapshot case final snapshot?)
                      DataBackupContents(
                        snapshot: snapshot,
                        source: DataBackupContentsSource.server,
                      )
                    else
                      Text(context.loc.dataBackupMissing),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.result?.complete != true &&
                        state.inspection.snapshot != null)
                      BullButton.big(
                        label: state.result == null
                            ? context.loc.dataBackupRecover
                            : context.loc.retry,
                        disabled: state.busy,
                        loading: state.busy,
                        bgColor: context.appColors.primary,
                        textColor: context.appColors.onPrimary,
                        onPressed: () => context
                            .read<DataBackupRecoveryCubit>()
                            .recover(enableAfterRecovery: enableAfterRecovery),
                      ),
                    if (state.result?.complete == true ||
                        state.inspection.snapshot == null)
                      TextButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(state.result?.complete == true),
                        child: Text(context.loc.continueButton),
                      ),
                  ],
                ),
              ),
            ],
          ),
        },
      ),
    ),
  );
}
