import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
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
  Future<Result<void, SpFailure>> stopScan();

  @useResult
  Future<Result<void, SpFailure>> clearScanState();

  /// Whether a scan is running, tracked in Dart from notifications (no FFI), so
  /// callers can skip blocking reads while the scan holds the inner lock.
  bool get isScanningCached;

  /// Restart the taproot electrum listener in place (reconnect + re-subscribe +
  /// re-sync). Used on app foreground to recover after Android killed the
  /// backgrounded socket. No-op when there is no live session.
  @useResult
  Future<Result<void, SpFailure>> restartElectrum();
}
