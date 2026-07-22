import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/coldcard_firmware_failure.dart';
import 'package:coldcard_firmware/coldcard_firmware.dart'
    show ColdcardModel, FirmwareRelease;
import 'package:meta/meta.dart';

/// A flow-scoped Coldcard firmware session.
///
/// Calls are intentionally ordered: [fetchLatest] must succeed before [downloadAndVerify], and [downloadAndVerify] must succeed before [saveVerifiedFirmware].
/// Starting a new fetch or download invalidates any firmware verified by an earlier attempt.
/// Each method fails closed when its prerequisite has not completed.
abstract interface class ColdcardFirmwareRepository {
  /// Starts a fresh session and returns the latest signed release metadata.
  @useResult
  Future<Result<FirmwareRelease, ColdcardFirmwareFailure>> fetchLatest(
    ColdcardModel model,
  );

  /// Downloads the release retained by [fetchLatest], then verifies it.
  @useResult
  Future<Result<void, ColdcardFirmwareFailure>> downloadAndVerify({
    void Function(int received, int? total)? onProgress,
    void Function()? onVerifying,
  });

  /// Saves only the opaque firmware retained by a successful verification.
  ///
  /// `Ok(false)` means the user cancelled the destination picker.
  @useResult
  Future<Result<bool, ColdcardFirmwareFailure>> saveVerifiedFirmware();

  /// Cancels an in-flight download and invalidates verified session state.
  void cancelDownload();
}
