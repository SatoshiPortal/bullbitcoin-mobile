import 'package:bull_logger/bull_logger.dart';

/// Worker messages contain fixed text and safe operation metadata only.
enum WriterLogLevel { info, fine, warning, severe }

typedef WriterDiagnosticSink =
    void Function(WriterLogLevel level, String message);

/// The foreground owns the persisted support log and reporter routing.
void persistWriterDiagnostic(WriterLogLevel level, String message) {
  switch (level) {
    case WriterLogLevel.info:
      log.info(message);
    case WriterLogLevel.fine:
      log.fine(message);
    case WriterLogLevel.warning:
      log.warning(message);
    case WriterLogLevel.severe:
      log.severe(message: message, error: 'storage', trace: StackTrace.empty);
  }
}
