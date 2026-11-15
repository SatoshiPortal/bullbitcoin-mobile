import 'dart:async';

import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

import '../../domain/entities/backup_monitoring.dart';
import '../../domain/recoverbull_failure.dart';
import '../../l10n/context_localizations.dart';
import '../../presentation/backup_monitoring_cubit.dart';

/// Persisted advisory alerts are visible after the host's normal unlock flow.
/// This widget only observes local state: mounting/resuming never polls.
class BackupAlarmOverlay extends StatefulWidget {
  final Widget child;
  final BackupMonitoringCubit? Function() create;
  final void Function(BuildContext) onOpen;
  const BackupAlarmOverlay({
    super.key,
    required this.child,
    required this.create,
    required this.onOpen,
  });

  @override
  State<BackupAlarmOverlay> createState() => _BackupAlarmOverlayState();
}

class _BackupAlarmOverlayState extends State<BackupAlarmOverlay> {
  late final BackupMonitoringCubit? _cubit = widget.create();

  @override
  void dispose() {
    unawaited(_cubit?.close() ?? Future.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = _cubit;
    if (cubit == null) return widget.child;
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: BullSpacing.lg,
          right: BullSpacing.lg,
          bottom: BullSpacing.xl,
          child: SafeArea(
            child:
                BlocBuilder<
                  BackupMonitoringCubit,
                  Result<BackupMonitoring, RecoverBullFailure>?
                >(
                  bloc: cubit,
                  builder: (context, state) => switch (state) {
                    Ok(:final value) when value.alerts.isNotEmpty =>
                      BullButton.small(
                        label: context.loc.recoverbullMonitoringTitle,
                        onPressed: () => widget.onOpen(context),
                        bgColor: context.bull.primary,
                        textColor: context.bull.onPrimary,
                      ),
                    _ => const SizedBox.shrink(),
                  },
                ),
          ),
        ),
      ],
    );
  }
}
