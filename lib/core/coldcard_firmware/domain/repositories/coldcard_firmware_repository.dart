import 'package:bb_mobile/core/coldcard_firmware/domain/entities/coldcard_device.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/coldcard_firmware_failure.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/entities/coldcard_firmware_release_entity.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/entities/verified_coldcard_firmware_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

abstract interface class ColdcardFirmwareRepository {
  /// The latest firmware Coinkite currently offers for [device], cross-checked against the PGP-verified release manifest.
  @useResult
  Future<Result<ColdcardFirmwareReleaseEntity, ColdcardFirmwareFailure>>
  fetchLatest(ColdcardDevice device);

  /// Downloads [release] and verifies it (manifest signature by the pinned Coinkite key + SHA-256 match). [onProgress] reports download progress; [onVerifying] fires once when the download completed and verification starts.
  @useResult
  Future<Result<VerifiedColdcardFirmwareEntity, ColdcardFirmwareFailure>>
  downloadAndVerify(
    ColdcardFirmwareReleaseEntity release, {
    void Function(int received, int? total)? onProgress,
    void Function()? onVerifying,
  });

  /// Lets the user pick a destination (any folder, including a microSD card via the system picker) and writes the verified firmware there under its original filename. Ok(false) means the user cancelled the picker.
  @useResult
  Future<Result<bool, ColdcardFirmwareFailure>> saveToFile(
    VerifiedColdcardFirmwareEntity firmware,
  );

  /// Aborts an in-flight download, if any. Called when the user leaves the flow so the transfer doesn't keep running in the background.
  void cancelDownload();
}
