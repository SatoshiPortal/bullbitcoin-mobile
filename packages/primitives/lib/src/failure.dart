/// The base of every modeled, recoverable failure in the codebase.
///
/// A [Failure] is a value returned in [Result], never thrown. Reserve
/// `dart:core` `Error` for programmer bugs that should crash to Sentry.
abstract class Failure {
  final String? logMessage;

  const Failure([this.logMessage]);

  /// The type only. [logMessage] may carry what a boundary chose to record — a foreign message, a storage key — and interpolating a failure into a log, an exception or a UI string must not carry it along by accident. Read [logMessage] where it is wanted.
  @override
  String toString() => '$runtimeType';
}
