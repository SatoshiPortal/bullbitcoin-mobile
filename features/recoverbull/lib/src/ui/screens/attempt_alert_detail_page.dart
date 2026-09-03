import 'package:flutter/material.dart';

import '../../../generated/l10n/recoverbull_localizations.dart';
import '../../public/recoverbull.dart';

class RecoverBullAttemptAlertDetailPage extends StatelessWidget {
  final List<RecoverBullAttemptAlert> sourceAlerts;

  const RecoverBullAttemptAlertDetailPage({
    super.key,
    required this.sourceAlerts,
  }) : assert(sourceAlerts.length > 0);

  @override
  Widget build(BuildContext context) {
    final l10n = RecoverBullLocalizations.of(context);
    final lockout = sourceAlerts.cast<RecoverBullAttemptAlert?>().firstWhere(
      (alert) => alert!.kind == RecoverBullAttemptAlertKind.targetedLockout,
      orElse: () => null,
    );
    final suspicious = sourceAlerts.cast<RecoverBullAttemptAlert?>().firstWhere(
      (alert) => alert!.kind == RecoverBullAttemptAlertKind.suspiciousActivity,
      orElse: () => null,
    );
    final reference = sourceAlerts
        .map((alert) => alert.backupReference)
        .firstWhere((reference) => reference != null, orElse: () => null);
    final security = lockout != null || suspicious != null;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.recoverbullAttemptAlertDetailsTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (reference case final value?)
              Text(l10n.recoverbullAttemptAlertReference(value)),
            if (suspicious?.observedTotal case final observed?)
              Text(
                l10n.recoverbullAttemptAlertAttempts(
                  suspicious!.expectedTotal ?? 0,
                  observed,
                ),
              ),
            if (suspicious?.windowStartedAt case final window?)
              Text(
                l10n.recoverbullAttemptAlertWindow(
                  MaterialLocalizations.of(
                    context,
                  ).formatMediumDate(window.toLocal()),
                ),
              ),
            if (security) ...[
              const SizedBox(height: 16),
              if (suspicious != null)
                Text(
                  l10n.recoverbullAttemptMonitoringSuspiciousActivityAnnouncement,
                ),
              if (lockout != null) ...[
                if (suspicious != null) const SizedBox(height: 12),
                Text(l10n.recoverbullAttemptMonitoringLockoutAnnouncement),
              ],
              const SizedBox(height: 12),
              Text(l10n.recoverbullAttemptAlertAction),
            ],
            if (lockout != null) ...[
              const SizedBox(height: 8),
              Text(l10n.recoverbullAttemptAlertLockoutGuidance),
            ],
            if (!security) ...[
              const SizedBox(height: 16),
              Text(l10n.recoverbullAttemptAlertInformational),
            ],
          ],
        ),
      ),
    );
  }
}
