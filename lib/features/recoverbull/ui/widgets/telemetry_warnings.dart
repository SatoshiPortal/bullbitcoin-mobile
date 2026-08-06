import 'package:bb_mobile/core/recoverbull/domain/entity/recoverbull_telemetry_alert.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/features/recoverbull/presentation/telemetry/recoverbull_telemetry_cubit.dart';
import 'package:bb_mobile/features/recoverbull/presentation/telemetry/recoverbull_telemetry_state.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Renders the advisory brute-force telemetry alerts as warning cards.
///
/// Mounted on the wallet home (inside the warnings area) and the backup
/// settings screen. Strong warnings open a bottom sheet with the full copy;
/// service pressure and soft warnings are inline only.
///
/// All copy follows the trust model: "unknown/suspicious activity", never
/// "confirmed attack", always paired with "check whether it was you or
/// another of your devices" and "never enter your seed or password because
/// of this alert".
class RecoverbullTelemetryWarnings extends StatelessWidget {
  const RecoverbullTelemetryWarnings({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecoverbullTelemetryCubit, RecoverbullTelemetryState>(
      bloc: locator<RecoverbullTelemetryCubit>(),
      builder: (context, state) {
        if (state.alerts.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final alert in state.alerts) ...[
              _AlertCard(alert: alert),
              const Gap(5),
            ],
          ],
        );
      },
    );
  }
}

class _AlertCard extends StatelessWidget {
  final RecoverbullTelemetryAlert alert;

  const _AlertCard({required this.alert});

  bool get _isStrong =>
      alert is SuspiciousActivityAlert || alert is TargetedLockoutAlert;

  @override
  Widget build(BuildContext context) {
    final (title, body) = _alertCopy(context, alert);
    final isStrong = _isStrong;

    return InfoCard(
      title: title.isEmpty ? null : title,
      description: body,
      tagColor: isStrong
          ? context.appColors.error
          : context.appColors.textMuted,
      bgColor: isStrong
          ? context.appColors.errorContainer
          : context.appColors.surfaceContainerHighest,
      // strong warnings open the full copy; every other notice is
      // dismissible on tap, so nothing sits on the home screen forever
      onTap: isStrong
          ? () => RecoverbullTelemetryAlertBottomSheet.show(context, alert)
          : () => locator<RecoverbullTelemetryCubit>().dismiss(alert),
    );
  }

  (String, String) _alertCopy(
    BuildContext context,
    RecoverbullTelemetryAlert alert,
  ) {
    final loc = context.loc;
    return switch (alert) {
      SuspiciousActivityAlert(:final observedTotal, :final expectedTotal) => (
        loc.recoverbullTelemetrySuspiciousActivityTitle,
        loc.recoverbullTelemetrySuspiciousActivityBody(
          observedTotal,
          expectedTotal,
        ),
      ),
      TargetedLockoutAlert() => (
        loc.recoverbullTelemetryLockoutTitle,
        loc.recoverbullTelemetryLockoutBody,
      ),
      ServicePressureAlert() => ('', loc.recoverbullTelemetryServicePressure),
      // no fabricated duration when monitoring never succeeded yet
      TelemetryUnavailableAlert(:final since) => (
        '',
        since == null
            ? loc.recoverbullTelemetryUnavailableUnknownDuration
            : loc.recoverbullTelemetryUnavailable(since.inDays),
      ),
      CountersWipedAlert() => ('', loc.recoverbullTelemetryCountersWiped),
    };
  }
}

/// The bottom sheet shown for strong telemetry warnings (suspicious
/// activity, targeted lockout): full copy plus an acknowledgement button.
class RecoverbullTelemetryAlertBottomSheet extends StatelessWidget {
  final RecoverbullTelemetryAlert alert;

  const RecoverbullTelemetryAlertBottomSheet({super.key, required this.alert});

  static Future<void> show(
    BuildContext context,
    RecoverbullTelemetryAlert alert,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RecoverbullTelemetryAlertBottomSheet(alert: alert),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (title, body) = _alertCopy(context, alert);
    final backupIdHash = switch (alert) {
      SuspiciousActivityAlert(:final backupIdHash) => backupIdHash,
      TargetedLockoutAlert(:final backupIdHash) => backupIdHash,
      _ => null,
    };

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title.isNotEmpty)
              Text(
                title,
                style: context.font.titleLarge,
                textAlign: TextAlign.center,
              ),
            const Gap(16),
            Text(body, style: context.font.bodyMedium),
            const Gap(24),
            FilledButton(
              onPressed: () {
                if (backupIdHash != null) {
                  locator<RecoverbullTelemetryCubit>().acknowledge(
                    backupIdHash: backupIdHash,
                  );
                }
                Navigator.of(context).pop();
              },
              child: Text(context.loc.recoverbullTelemetryDismiss),
            ),
          ],
        ),
      ),
    );
  }

  (String, String) _alertCopy(
    BuildContext context,
    RecoverbullTelemetryAlert alert,
  ) {
    final loc = context.loc;
    return switch (alert) {
      SuspiciousActivityAlert(:final observedTotal, :final expectedTotal) => (
        loc.recoverbullTelemetrySuspiciousActivityTitle,
        loc.recoverbullTelemetrySuspiciousActivityBody(
          observedTotal,
          expectedTotal,
        ),
      ),
      TargetedLockoutAlert() => (
        loc.recoverbullTelemetryLockoutTitle,
        loc.recoverbullTelemetryLockoutBody,
      ),
      ServicePressureAlert() => ('', loc.recoverbullTelemetryServicePressure),
      // no fabricated duration when monitoring never succeeded yet
      TelemetryUnavailableAlert(:final since) => (
        '',
        since == null
            ? loc.recoverbullTelemetryUnavailableUnknownDuration
            : loc.recoverbullTelemetryUnavailable(since.inDays),
      ),
      CountersWipedAlert() => ('', loc.recoverbullTelemetryCountersWiped),
    };
  }
}
