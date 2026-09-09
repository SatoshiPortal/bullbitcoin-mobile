/// Minimal logging seam: silent by default (library rule — the app logs, the
/// package returns values and errors). The app assigns its own implementation
/// once at startup: `swapsLog = MyAppSwapsLog();`
abstract class SwapsLog {
  void fine(String message);
  void info(String message);
  void warning(String message);
  void severe(String message, {Object? error, StackTrace? trace});
  Future<void> flush();
}

class _NoopLog implements SwapsLog {
  const _NoopLog();
  @override
  void fine(String message) {}
  @override
  void info(String message) {}
  @override
  void warning(String message) {}
  @override
  void severe(String message, {Object? error, StackTrace? trace}) {}
  @override
  Future<void> flush() async {}
}

SwapsLog swapsLog = const _NoopLog();
