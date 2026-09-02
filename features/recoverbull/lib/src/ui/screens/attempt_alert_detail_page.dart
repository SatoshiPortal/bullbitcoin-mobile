import 'package:flutter/material.dart';

import '../../../generated/l10n/recoverbull_localizations.dart';
import '../../public/recoverbull.dart';

class RecoverBullAttemptAlertDetailPage extends StatelessWidget {
  final RecoverBullAttemptAlert alert;

  const RecoverBullAttemptAlertDetailPage({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final l10n = RecoverBullLocalizations.of(context);
    final security =
        alert.kind == RecoverBullAttemptAlertKind.targetedLockout ||
        alert.kind == RecoverBullAttemptAlertKind.suspiciousActivity;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.recoverbullAttemptAlertDetailsTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (alert.backupReference case final reference?)
              Text(l10n.recoverbullAttemptAlertReference(reference)),
            if (alert.observedTotal case final observed?)
              Text(
                l10n.recoverbullAttemptAlertAttempts(
                  observed,
                  alert.expectedTotal ?? 0,
                ),
              ),
            if (alert.windowStartedAt case final window?)
              Text(
                l10n.recoverbullAttemptAlertWindow(
                  MaterialLocalizations.of(
                    context,
                  ).formatMediumDate(window.toLocal()),
                ),
              ),
            if (security) ...[
              const SizedBox(height: 16),
              Text(l10n.recoverbullAttemptAlertAction),
            ],
            if (alert.kind == RecoverBullAttemptAlertKind.targetedLockout) ...[
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
