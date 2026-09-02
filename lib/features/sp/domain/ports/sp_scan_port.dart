import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';

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
  @useResult
  Future<Result<void, SpFailure>> scanOnce({int? startHeight});
}
