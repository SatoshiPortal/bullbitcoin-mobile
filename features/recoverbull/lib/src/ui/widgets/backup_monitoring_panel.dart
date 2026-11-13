import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';
import '../../domain/entities/backup_monitoring.dart';
import '../../domain/recoverbull_failure.dart';
import '../../l10n/context_localizations.dart';
import '../../presentation/backup_monitoring_cubit.dart';
import '../../presentation/recoverbull_failure_l10n.dart';

/// Generic advisory copy only, including the accessibility tree.
class BackupMonitoringPanel extends StatelessWidget {
  final BackupMonitoringCubit cubit;
  const BackupMonitoringPanel({super.key, required this.cubit});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<
        BackupMonitoringCubit,
        Result<BackupMonitoring, RecoverBullFailure>?
      >(
        bloc: cubit,
        builder: (context, state) => switch (state) {
          null => BullText(
            context.loc.recoverbullPleaseWait,
            style: context.bullText.bodyLarge,
          ),
          Err(:final failure) => BullText(
            failure.toTranslated(context),
            style: context.bullText.bodyLarge,
          ),
          Ok(:final value) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (value.unknown)
                BullText(
                  context.loc.recoverbullMonitoringUnknown,
                  style: context.bullText.bodyLarge,
                ),
              if (value.alerts.any(
                (alert) => alert.kind == BackupAlertKind.unexplainedActivity,
              ))
                BullText(
                  context.loc.recoverbullActivityAlert,
                  style: context.bullText.bodyLarge,
                ),
              if (value.alerts.any(
                (alert) => alert.kind == BackupAlertKind.lockout,
              ))
                BullText(
                  context.loc.recoverbullLockoutAlert,
                  style: context.bullText.bodyLarge,
                ),
              if (value.alerts.isNotEmpty)
                BullButton.small(
                  label: context.loc.recoverbullDismissAlerts,
                  onPressed: cubit.acknowledge,
                  bgColor: context.bull.primary,
                  textColor: context.bull.onPrimary,
                ),
            ],
          ),
        },
      );
}
