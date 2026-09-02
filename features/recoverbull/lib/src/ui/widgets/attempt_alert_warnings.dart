import 'package:flutter/material.dart';

import '../../../generated/l10n/recoverbull_localizations.dart';
import '../../public/recoverbull.dart';
import '../support.dart';
import '../screens/attempt_alert_detail_page.dart';

/// Opaque attempt monitoring advisory for shell placement. It accepts only public alert types and never renders identifiers, hashes, or URLs.
class RecoverBullAttemptAlertWarnings extends StatelessWidget {
  final RecoverBullAttemptMonitoringController controller;
  const RecoverBullAttemptAlertWarnings({super.key, required this.controller});
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<RecoverBullAttemptAlert>>(
        stream: controller.alerts,
        builder: (context, snapshot) {
          final alerts = snapshot.data ?? const <RecoverBullAttemptAlert>[];
          if (alerts.isEmpty) return const SizedBox.shrink();
          final l10n = RecoverBullLocalizations.of(context);
          return Column(
            children: [
              for (final alert in alerts)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      color: context.appColors.surface,
                      child: InfoCard(
                        title: _title(l10n, alert),
                        description: _description(l10n, alert),
                        tagColor: _isSecurityAlert(alert)
                            ? context.appColors.error
                            : context.appColors.primary,
                        bgColor: _isSecurityAlert(alert)
                            ? context.appColors.errorContainer
                            : context.appColors.cardBackground,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                RecoverBullAttemptAlertDetailPage(alert: alert),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => controller.acknowledge(alert),
                        child: Text(l10n.recoverbullAttemptMonitoringDismiss),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      );

  bool _isSecurityAlert(RecoverBullAttemptAlert alert) =>
      alert.kind == RecoverBullAttemptAlertKind.suspiciousActivity ||
      alert.kind == RecoverBullAttemptAlertKind.targetedLockout;

  String _description(
    RecoverBullLocalizations l10n,
    RecoverBullAttemptAlert alert,
  ) => switch (alert.kind) {
    RecoverBullAttemptAlertKind.suspiciousActivity =>
      l10n.recoverbullAttemptMonitoringSuspiciousActivityBody,
    RecoverBullAttemptAlertKind.targetedLockout =>
      l10n.recoverbullAttemptMonitoringLockoutBody,
    RecoverBullAttemptAlertKind.servicePressure =>
      l10n.recoverbullAttemptMonitoringServicePressure,
    RecoverBullAttemptAlertKind.unavailable =>
      l10n.recoverbullAttemptMonitoringUnavailableUnknownDuration,
    RecoverBullAttemptAlertKind.countersWiped =>
      l10n.recoverbullAttemptMonitoringCountersWiped,
  };

  String _title(RecoverBullLocalizations l10n, RecoverBullAttemptAlert alert) =>
      switch (alert.kind) {
        RecoverBullAttemptAlertKind.suspiciousActivity =>
          l10n.recoverbullAttemptMonitoringSuspiciousActivityTitle,
        RecoverBullAttemptAlertKind.targetedLockout =>
          l10n.recoverbullAttemptMonitoringLockoutTitle,
        RecoverBullAttemptAlertKind.servicePressure =>
          l10n.recoverbullAttemptMonitoringServicePressure,
        RecoverBullAttemptAlertKind.unavailable =>
          l10n.recoverbullAttemptMonitoringUnavailableUnknownDuration,
        RecoverBullAttemptAlertKind.countersWiped =>
          l10n.recoverbullAttemptMonitoringCountersWiped,
      };
}
