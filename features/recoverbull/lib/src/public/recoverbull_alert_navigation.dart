import 'package:flutter/material.dart';

import '../ui/screens/attempt_alert_detail_page.dart';
import 'recoverbull.dart';

void openRecoverBullAttemptAlertDetails(
  BuildContext context,
  List<RecoverBullAttemptAlert> sourceAlerts,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          RecoverBullAttemptAlertDetailPage(sourceAlerts: sourceAlerts),
    ),
  );
}
