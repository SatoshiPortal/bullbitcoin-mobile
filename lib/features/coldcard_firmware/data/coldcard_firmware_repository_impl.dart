import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/coldcard_firmware_failure.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/repositories/coldcard_firmware_repository.dart';
import 'package:coldcard_firmware/coldcard_firmware.dart' as ckf;
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

class ColdcardFirmwareRepositoryImpl implements ColdcardFirmwareRepository {
  final ckf.ColdcardFirmwareClient Function() _clientFactory;

  ckf.ColdcardFirmwareClient? _client;
  ckf.FirmwareRelease? _fetchedRelease;
  ckf.VerifiedFirmware? _verifiedFirmware;
  CancelToken? _downloadCancelToken;

  ColdcardFirmwareRepositoryImpl({
    ckf.ColdcardFirmwareClient Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? ckf.ColdcardFirmwareClient.new;

  @override
  Future<Result<ckf.FirmwareRelease, ColdcardFirmwareFailure>> fetchLatest(
    ckf.ColdcardModel model,
  ) async {
    _downloadCancelToken?.cancel();
    _downloadCancelToken = null;
    _client = null;
    _fetchedRelease = null;
    _verifiedFirmware = null;

    try {
      final client = _clientFactory();
      _client = client;
      final release = await client.fetchLatest(model);
      _fetchedRelease = release;
      return Ok(release);
    } on ckf.ColdcardFirmwareException catch (error, trace) {
      log.warning(
        'Coldcard firmware discovery failed',
        error: error,
        trace: trace,
      );
      return Err(_toFailure(error));
    } on Exception catch (error, trace) {
      log.severe(
        message: 'Unexpected Coldcard firmware discovery failure',
        error: error,
        trace: trace,
      );
      return Err(ColdcardFirmwareUnexpectedFailure(error.toString()));
    }
  }

  @override
  Future<Result<void, ColdcardFirmwareFailure>> downloadAndVerify({
    void Function(int received, int? total)? onProgress,
    void Function()? onVerifying,
  }) async {
    _verifiedFirmware = null;

    final client = _client;
    final release = _fetchedRelease;
    if (client == null || release == null) {
      return const Err(
        ColdcardFirmwareDiscoveryFailure(
          'fetchLatest must succeed before downloadAndVerify',
        ),
      );
    }

    final token = CancelToken();
    _downloadCancelToken = token;

    try {
      final downloaded = await client.download(
        release,
        onProgress: onProgress,
        cancelToken: token,
      );
      onVerifying?.call();
      final verified = await client.verify(downloaded);

      // A cancellation or overlapping attempt invalidates this result even if verification happened to finish after that newer event.
      if (!identical(_downloadCancelToken, token) || token.isCancelled) {
        return const Err(
          ColdcardFirmwareNetworkFailure('firmware download cancelled'),
        );
      }

      _verifiedFirmware = verified;
      return const Ok(null);
    } on ckf.ColdcardFirmwareException catch (error, trace) {
      log.warning(
        'Coldcard firmware download or verification failed',
        error: error,
        trace: trace,
      );
      return Err(_toFailure(error));
    } on Exception catch (error, trace) {
      log.severe(
        message: 'Unexpected Coldcard firmware verification failure',
        error: error,
        trace: trace,
      );
      return Err(ColdcardFirmwareUnexpectedFailure(error.toString()));
    } finally {
      if (identical(_downloadCancelToken, token)) {
        _downloadCancelToken = null;
      }
    }
  }

  @override
  Future<Result<bool, ColdcardFirmwareFailure>> saveVerifiedFirmware() async {
    final firmware = _verifiedFirmware;
    if (firmware == null) {
      return const Err(
        ColdcardFirmwareVerificationFailure(
          'downloadAndVerify must succeed before saveVerifiedFirmware',
        ),
      );
    }

    try {
      final path = await FilePicker.platform.saveFile(
        fileName: firmware.release.filename,
        bytes: firmware.bytes,
      );
      return Ok(path != null);
    } on Exception catch (error, trace) {
      log.warning(
        'Saving verified Coldcard firmware failed',
        error: error,
        trace: trace,
      );
      return Err(ColdcardFirmwareSaveFailure(error.toString()));
    }
  }

  @override
  void cancelDownload() {
    _downloadCancelToken?.cancel();
    _downloadCancelToken = null;
    _verifiedFirmware = null;
  }

  static ColdcardFirmwareFailure _toFailure(
    ckf.ColdcardFirmwareException error,
  ) {
    return switch (error) {
      ckf.FirmwareNetworkException() => ColdcardFirmwareNetworkFailure(
        error.message,
      ),
      ckf.DiscoveryParseException() || ckf.ResponseTooLargeException() =>
        ColdcardFirmwareDiscoveryFailure(error.message),
      ckf.ReleaseNotInManifestException() ||
      ckf.ManifestSignatureException() ||
      ckf.ManifestWrongKeyException() ||
      ckf.FirmwareHashMismatchException() ||
      ckf.FirmwareTooLargeException() => ColdcardFirmwareVerificationFailure(
        error.message,
      ),
    };
  }
}
