import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';
import '../domain/entities/backup_monitoring.dart';
import '../domain/recoverbull_failure.dart';
import '../domain/usecases/watch_backup_monitoring_usecase.dart';
import '../domain/usecases/acknowledge_backup_alerts_usecase.dart';

final class BackupMonitoringCubit
    extends Cubit<Result<BackupMonitoring, RecoverBullFailure>?> {
  final AcknowledgeBackupAlertsUsecase _acknowledge;
  late final StreamSubscription<Result<BackupMonitoring, RecoverBullFailure>>
  _subscription;

  BackupMonitoringCubit(WatchBackupMonitoringUsecase watch, this._acknowledge)
    : super(null) {
    _subscription = watch.execute().listen((value) {
      if (!isClosed) emit(value);
    });
  }

  Future<void> acknowledge() async {
    final current = state;
    if (current case Ok(:final value)) {
      final result = await _acknowledge.execute(value.alerts);
      if (result case Err(:final failure) when !isClosed) emit(Err(failure));
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
