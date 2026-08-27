/// The base of every modeled, recoverable failure in the codebase.
///
/// A [Failure] is a value returned in [Result], never thrown. Reserve
/// `dart:core` `Error` for programmer bugs that should crash to Sentry.
abstract class Failure {
  final String? logMessage;

  const Failure([this.logMessage]);
}
