import 'dart:async';

import 'package:bull_recoverbull/bull_recoverbull.dart' show RecoverBullFeature;

import 'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart';
import 'package:bull_recoverbull/src/domain/entities/backup_monitoring.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/repositories/attempt_monitoring_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/acknowledge_backup_alerts_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/watch_backup_monitoring_usecase.dart';
import 'package:bull_recoverbull/src/presentation/backup_monitoring_cubit.dart';
import 'package:bull_recoverbull/src/ui/widgets/backup_monitoring_panel.dart';
import 'package:bull_ui/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  testWidgets(
    'persisted categories render generically and dismiss through the usecase',
    (tester) async {
      final repository = _Monitoring();
      final cubit = BackupMonitoringCubit(
        WatchBackupMonitoringUsecase(repository),
        AcknowledgeBackupAlertsUsecase(repository),
      );
      addTearDown(() async {
        await cubit.close();
        await repository.changes.close();
      });
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: testBullExtensions),
          localizationsDelegates: RecoverBullFeature.localizationsDelegates,
          supportedLocales: RecoverBullLocalizations.supportedLocales,
          home: Scaffold(body: BackupMonitoringPanel(cubit: cubit)),
        ),
      );
      await tester.pumpAndSettle();
      repository.changes.add(
        Ok(
          BackupMonitoring(
            unknown: true,
            alerts: const [
              BackupAlert(9173, BackupAlertKind.unexplainedActivity),
              BackupAlert(9471, BackupAlertKind.lockout),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('this device could not explain'),
        findsOneWidget,
      );
      expect(find.textContaining('coverage is unknown'), findsOneWidget);
      expect(find.textContaining('limited access'), findsOneWidget);
      expect(find.textContaining('9173'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('9173|9471|digest|observed_total')),
        findsNothing,
      );
      await tester.tap(find.text('Dismiss alerts'));
      await tester.pumpAndSettle();
      expect(repository.acknowledged, [9173, 9471]);
      expect(find.text('Dismiss alerts'), findsNothing);
      semantics.dispose();
    },
  );
}

final class _Monitoring extends Fake implements AttemptMonitoringRepository {
  final changes =
      StreamController<
        Result<BackupMonitoring, RecoverBullFailure>
      >.broadcast();
  final acknowledged = <int>[];
  @override
  Stream<Result<BackupMonitoring, RecoverBullFailure>> watchStatus() =>
      changes.stream;
  @override
  Future<Result<void, RecoverBullFailure>> acknowledge(
    int acknowledgement,
  ) async {
    acknowledged.add(acknowledgement);
    if (acknowledged.length == 2) {
      changes.add(Ok(BackupMonitoring(unknown: true, alerts: const [])));
    }
    return const Ok(null);
  }
}
