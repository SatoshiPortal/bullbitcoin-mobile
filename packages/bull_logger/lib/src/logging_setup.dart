import 'dart:async';
import 'dart:io';

import 'diagnostic_context.dart';
import 'logger.dart';

/// Initializes support logs, deferring diagnostic probes until an explicit refresh.
Future<void> initializeLogging({
  required Directory directory,
  bool background = false,
  LoggerReporter? reporter,
  DiagnosticContextSource? diagnosticContextSource,
}) async {
  final diagnosticContextProvider = background
      ? null
      : DiagnosticContextProvider(
          diagnosticContextSource ?? PlatformDiagnosticContextSource(),
        );
  log = Logger.replace(
    directory: directory,
    background: background,
    diagnosticContextLoader: diagnosticContextProvider?.load,
    reporter: reporter,
  );
  await log.ensureLogsExist(writeDiagnosticContext: false);
  if (!background) {
    // Pruning is per isolate; background files are pruned by their own tasks.
    unawaited(log.prune());
  }
}
