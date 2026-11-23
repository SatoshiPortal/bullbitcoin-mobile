import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:meta/meta.dart';

/// Scan operations that cannot start a scan: stopping one, clearing the cursor,
/// reading whether one is running, and restarting the electrum listener.
///
/// Deliberately separate from [SpScanPort]: these have several consumers, and
/// none of them may reach `scanOnce`.
abstract interface class SpScanControlPort {
  /// Flip the cancel flag. The scan tears down asynchronously and reports
  /// stopped/completed on the notification stream.
  @useResult
  Future<Result<void, SilentFailure>> stopScan();

  @useResult
  Future<Result<void, SilentFailure>> clearScanState();

  /// Whether a scan is running, tracked in Dart from notifications (no FFI), so
  /// callers can skip blocking reads while the scan holds the inner lock.
  bool get isScanningCached;

  /// Restart the electrum listener in place (reconnect + re-subscribe +
  /// re-sync). No-op when there is no live session.
  @useResult
  Future<Result<void, SilentFailure>> restartElectrum();
}
