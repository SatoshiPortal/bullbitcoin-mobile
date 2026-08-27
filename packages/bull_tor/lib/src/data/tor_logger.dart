typedef TorLogCallback =
    void Function(Object? message, {Object? error, StackTrace? trace});

final class TorLogger {
  final TorLogCallback? configCallback;
  final TorLogCallback? fineCallback;
  final TorLogCallback? warningCallback;

  const TorLogger({
    this.configCallback,
    this.fineCallback,
    this.warningCallback,
  });

  void config(Object? message, {Object? error, StackTrace? trace}) =>
      configCallback?.call(message, error: error, trace: trace);

  void fine(Object? message, {Object? error, StackTrace? trace}) =>
      fineCallback?.call(message, error: error, trace: trace);

  void warning(Object? message, {Object? error, StackTrace? trace}) =>
      warningCallback?.call(message, error: error, trace: trace);
}
