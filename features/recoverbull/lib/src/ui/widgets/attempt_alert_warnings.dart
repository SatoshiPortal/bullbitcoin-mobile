import 'package:flutter/material.dart';

import '../../../generated/l10n/recoverbull_localizations.dart';
import '../../public/recoverbull.dart';

/// Opaque attempt monitoring advisory for shell placement. It accepts only public alert
/// types and never renders identifiers, hashes, or URLs.
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
                Card(
                  child: ListTile(
                    title: Text(_title(l10n, alert)),
                    subtitle: _subtitle(l10n, alert),
                    trailing: TextButton(
                      onPressed: () => controller.acknowledge(alert),
                      child: Text(l10n.recoverbullAttemptMonitoringDismiss),
                    ),
                  ),
                ),
            ],
          );
        },
      );

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

  Widget? _subtitle(
    RecoverBullLocalizations l10n,
    RecoverBullAttemptAlert alert,
  ) => switch (alert.kind) {
    RecoverBullAttemptAlertKind.suspiciousActivity => Text(
      l10n.recoverbullAttemptMonitoringSuspiciousActivityBody,
    ),
    RecoverBullAttemptAlertKind.targetedLockout => Text(
      l10n.recoverbullAttemptMonitoringLockoutBody,
    ),
    _ => null,
  };
}
