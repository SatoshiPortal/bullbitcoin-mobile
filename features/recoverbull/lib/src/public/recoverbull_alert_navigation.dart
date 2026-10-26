import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

import '../router/recoverbull_router.dart';
import 'recoverbull.dart';

void openRecoverBullAttemptAlertDetails(
  BuildContext context,
  List<RecoverBullAttemptAlert> sourceAlerts,
) => context.pushNamed(
  RecoverBullRoute.recoverbullAttemptAlerts.name,
  extra: List<RecoverBullAttemptAlert>.unmodifiable(sourceAlerts),
);
