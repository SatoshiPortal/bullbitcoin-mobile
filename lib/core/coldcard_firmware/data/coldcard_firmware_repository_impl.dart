import 'package:bb_mobile/core/coldcard_firmware/domain/entities/coldcard_device.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/coldcard_firmware_failure.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/entities/coldcard_firmware_release_entity.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/repositories/coldcard_firmware_repository.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/entities/verified_coldcard_firmware_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:coldcard_firmware/coldcard_firmware.dart' as ckf;
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

class ColdcardFirmwareRepositoryImpl implements ColdcardFirmwareRepository {
  ColdcardFirmwareRepositoryImpl({
    ckf.ColdcardFirmwareClient Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? ckf.ColdcardFirmwareClient.new;

  final ckf.ColdcardFirmwareClient Function() _clientFactory;

  /// The client caches the verified manifest for its lifetime, so a fresh one is created per flow (each flow starts with [fetchLatest]) — a repository singleton must not pin week-old signed data.
  late ckf.ColdcardFirmwareClient _client = _clientFactory();

  CancelToken? _downloadCancelToken;

  /// The package release behind the last entity handed out: the opaque download/verify handle belongs to the data layer, so the entity crossing the domain boundary is matched back to it by filename.
  ckf.FirmwareRelease? _lastFetchedRelease;

  @override
  Future<Result<ColdcardFirmwareReleaseEntity, ColdcardFirmwareFailure>>
  fetchLatest(ColdcardDevice device) async {
    try {
      _client = _clientFactory();
      final release = await _client.fetchLatest(_toModel(device));
      _lastFetchedRelease = release;
      return Ok(_toReleaseEntity(device, release));
    } on ckf.ColdcardFirmwareException catch (e) {
      return Err(_toFailure(e));
    } catch (e) {
      return Err(ColdcardFirmwareUnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<VerifiedColdcardFirmwareEntity, ColdcardFirmwareFailure>>
  downloadAndVerify(
    ColdcardFirmwareReleaseEntity release, {
    void Function(int received, int? total)? onProgress,
    void Function()? onVerifying,
  }) async {
    try {
      var packageRelease = _lastFetchedRelease;
      // A fresh repository instance (e.g. after process restart) has no cached handle; re-discover and insist it's still the same release.
      if (packageRelease == null ||
          packageRelease.filename != release.filename) {
        packageRelease = await _client.fetchLatest(_toModel(release.device));
      }
      if (packageRelease.filename != release.filename) {
        return Err(
          ColdcardFirmwareDiscoveryFailure(
            'offered release changed: expected ${release.filename}, '
            'found ${packageRelease.filename}',
          ),
        );
      }
      _downloadCancelToken = CancelToken();
      final downloaded = await _client.download(
        packageRelease,
        onProgress: onProgress,
        cancelToken: _downloadCancelToken,
      );
      _downloadCancelToken = null;
      onVerifying?.call();
      final verified = await _client.verify(downloaded);
      return Ok(
        VerifiedColdcardFirmwareEntity(
          release: release,
          bytes: verified.bytes,
          sha256Hex: verified.sha256Hex,
          signerName: ckf.trustedSignerIdentity,
          signerFingerprintHex: verified.signerFingerprintHex,
        ),
      );
    } on ckf.ColdcardFirmwareException catch (e) {
      return Err(_toFailure(e));
    } catch (e) {
      return Err(ColdcardFirmwareUnexpectedFailure(e.toString()));
    }
  }

  @override
  void cancelDownload() {
    _downloadCancelToken?.cancel();
    _downloadCancelToken = null;
  }

  @override
  Future<Result<bool, ColdcardFirmwareFailure>> saveToFile(
    VerifiedColdcardFirmwareEntity firmware,
  ) async {
    try {
      final path = await FilePicker.platform.saveFile(
        fileName: firmware.release.filename,
        bytes: firmware.bytes,
      );
      return Ok(path != null);
    } catch (e) {
      return Err(ColdcardFirmwareSaveFailure(e.toString()));
    }
  }

  static ckf.ColdcardModel _toModel(ColdcardDevice device) => switch (device) {
    ColdcardDevice.q => ckf.ColdcardModel.q,
    ColdcardDevice.mk4 => ckf.ColdcardModel.mk4,
  };

  static ColdcardFirmwareReleaseEntity _toReleaseEntity(
    ColdcardDevice device,
    ckf.FirmwareRelease release,
  ) {
    return ColdcardFirmwareReleaseEntity(
      device: device,
      versionLabel: release.version.toString(),
      filename: release.filename,
      sha256Hex: release.expectedSha256Hex,
      releasedAt: _parseReleaseTimestamp(release.timestampRaw),
    );
  }

  /// Filename timestamps look like `2026-07-01T1727` — insert the colon so DateTime.parse accepts them.
  static DateTime? _parseReleaseTimestamp(String raw) {
    if (raw.length != 15) return null;
    return DateTime.tryParse('${raw.substring(0, 13)}:${raw.substring(13)}:00');
  }

  static ColdcardFirmwareFailure _toFailure(ckf.ColdcardFirmwareException e) {
    return switch (e) {
      ckf.FirmwareNetworkException() => ColdcardFirmwareNetworkFailure(
        e.message,
      ),
      ckf.DiscoveryParseException() || ckf.ResponseTooLargeException() =>
        ColdcardFirmwareDiscoveryFailure(e.message),
      ckf.ReleaseNotInManifestException() ||
      ckf.ManifestSignatureException() ||
      ckf.ManifestWrongKeyException() ||
      ckf.FirmwareHashMismatchException() ||
      ckf.FirmwareTooLargeException() => ColdcardFirmwareVerificationFailure(
        e.message,
      ),
    };
  }
}
