import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

export '../src/domain/logs_failure.dart';
export 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:primitives/primitives.dart';

import '../src/logs_locator.dart';
import '../src/logs_router.dart';
import '../src/domain/logs_failure.dart';
import '../src/domain/usecases/export_all_logs_usecase.dart';
import '../src/domain/usecases/share_all_logs_usecase.dart';

/// Public application-shell composition for the logs feature.
final class LogsFeature {
  const LogsFeature();

  void setup(GetIt locator) {
    LogsLocator.setup(locator);
    locator.registerLazySingleton<LogsFacade>(
      () => LogsFacade._(locator(), locator()),
    );
  }

  GoRoute get route => LogsRouter.route;
}

/// Public composition boundary for the logs feature.
final class LogsFacade {
  final ShareAllLogsUsecase _shareAll;
  final ExportAllLogsUsecase _exportAll;

  const LogsFacade._(this._shareAll, this._exportAll);

  /// Shares every persisted log through the configured platform adapter.
  Future<Result<void, LogsFailure>> shareAll() => _shareAll.execute();

  /// Exports every persisted log through the configured platform adapter.
  Future<Result<bool, LogsFailure>> exportAll() => _exportAll.execute();
}
