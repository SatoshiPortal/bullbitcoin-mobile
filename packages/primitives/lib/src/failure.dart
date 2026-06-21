/// The base of every modeled, recoverable failure in the codebase.
///
/// Copied verbatim (shape-for-shape) from the issue #1895 branch
/// (`1895-sanitize-all-user-facing-error-messages`) so that, whichever of
/// #1895 / `primitives` merges first, there is exactly ONE definition of
/// `Failure` and `Result`. Do not add fields the branch lacks.
///
/// A `Failure` is a *value* returned in [Result] — never thrown. Reserve
/// `dart:core` `Error` for programmer bugs that should crash to Sentry.
abstract class Failure {
  const Failure([this.logMessage]);

  /// For logs / Sentry ONLY. MUST never reach the UI.
  ///
  /// Boundaries that touch secret material (the `secrets` package) are required
  /// to sanitize this string before constructing the failure — redacting
  /// 12/24-word mnemonic sequences and 64-hex blobs — so a raw crypto error
  /// string can never echo secret input into a log sink.
  final String? logMessage;
}
