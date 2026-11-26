import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:meta/meta.dart';

/// The state an automatic scan was decided on.
///
/// The sync path reads the snapshot and its tip, then asks for a scan; between
/// those steps the session can be recycled or the user can stop or clear the
/// scan. Carrying the revision lets the repository refuse a decision that no
/// longer applies. The repository additionally checks live foreground and
/// opt-in at the native boundary, without passing a callback in the request.
typedef SpAutomaticScanAdmission = ({int revision});

/// The single Dart entry point to the Rust chain scan.
///
/// This port exists to hold exactly one method. `ScanSpWalletUsecase` is the
/// only class the locator hands it to, so "nothing else starts a scan" is a
/// fact the compiler enforces rather than something a grep has to police. Scan
/// control that cannot start a scan (stop, clear, the running flag) lives on
/// [SpScanControlPort] instead, so its consumers never see this method.
///
/// Do not widen this port, and do not inject it anywhere else. Both would give
/// the capability away.
abstract interface class SpScanPort {
  /// Run the one-shot scan. `startHeight` overrides where it begins (null
  /// resumes from the last scanned position). Returns as soon as the scan is
  /// spawned; progress arrives on the notification stream.
  ///
  /// [automatic] marks a scan the app started on its own: the repository checks
  /// its revision and a paused marker before spawning anything, and reports
  /// `Ok(null)` for a decision that no longer applies. An automatic launch
  /// never writes a persistent resume marker.
  @useResult
  Future<Result<void, SilentFailure>> scanOnce({
    int? startHeight,
    SpAutomaticScanAdmission? automatic,
  });
}
