/// Base type for every modeled, recoverable failure that crosses a layer
/// boundary as a value (carried by [Err], never thrown).
///
/// Distinct from `dart:core` `Error` (a programmer bug — never caught) and
/// `Exception` (thrown, low-level — caught at the data boundary and mapped into
/// a [Failure]). A [Failure] is Flutter-free; its user-facing message lives in a
/// presentation-layer `toTranslated(BuildContext)` extension, never here.
abstract class Failure {
  const Failure([this.logMessage]);

  /// For logs / Sentry ONLY. MUST never reach the UI.
  final String? logMessage;
}
