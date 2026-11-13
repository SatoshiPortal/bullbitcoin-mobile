import 'package:primitives/primitives.dart';

import '../recoverbull_failure.dart';
import '../repositories/attempt_monitoring_repository.dart';
import 'open_key_server_usecase.dart';

/// Called once by the foreground process composition, never by resume events.
final class CheckBackupMonitoringUsecase {
  final AttemptMonitoringRepository _monitoring;
  final OpenKeyServerUsecase _open;
  bool _started = false;

  CheckBackupMonitoringUsecase(this._monitoring, this._open);

  Future<Result<void, RecoverBullFailure>> execute() async {
    if (_started) return const Ok(null);
    _started = true;
    switch (await _monitoring.prepare()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: null):
        return const Ok(null);
      case Ok(value: final check?):
        switch (await _open.execute(
          expected: check.settings,
          monitoring: true,
        )) {
          case Err():
            return _monitoring.observe(check, null);
          case Ok(:final value):
            try {
              final snapshot = await value.attempts(check.digests);
              return await _monitoring.observe(check, switch (snapshot) {
                Ok(:final value) => value,
                Err() => null,
              });
            } finally {
              await value.close();
            }
        }
    }
  }
}
