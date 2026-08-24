import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/ledger/data/datasources/ledger_device_datasource.dart';
import 'package:bb_mobile/core/ledger/data/models/ledger_device_model.dart';
import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/data/ledger_exception.dart';
import 'package:bb_mobile/core/ledger/domain/ledger_failure.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class LedgerDeviceRepositoryImpl implements LedgerDeviceRepository {
  final LedgerDeviceDatasource _datasource;

  LedgerDeviceRepositoryImpl({required this._datasource});

  @override
  Future<Result<List<LedgerDeviceEntity>, LedgerFailure>> scanDevices({
    SignerDeviceEntity? deviceType,
  }) async {
    final scanned = await _guard(
      () => _datasource.scanDevices(deviceType: deviceType),
    );
    // The datasource reports what it saw. Requiring exactly one device is this
    // layer's policy, so it is decided here instead of being thrown from the
    // datasource and renamed on the way back up.
    return switch (scanned) {
      Err(:final failure) => Err<List<LedgerDeviceEntity>, LedgerFailure>(
        failure,
      ),
      Ok(:final value) when value.isEmpty =>
        const Err<List<LedgerDeviceEntity>, LedgerFailure>(
          LedgerNoDevicesFoundFailure(),
        ),
      Ok(:final value) when value.length > 1 =>
        const Err<List<LedgerDeviceEntity>, LedgerFailure>(
          LedgerMultipleDevicesFoundFailure(),
        ),
      Ok(:final value) => Ok<List<LedgerDeviceEntity>, LedgerFailure>(
        value.map((model) => model.toEntity()).toList(),
      ),
    };
  }

  @override
  Future<Result<void, LedgerFailure>> connectDevice(LedgerDeviceEntity device) {
    return _guard(() async {
      await _datasource.connectDevice(device.toModel());
    });
  }

  @override
  Future<Result<String, LedgerFailure>> getMasterFingerprint(
    LedgerDeviceEntity device,
  ) {
    return _guard(() => _datasource.getMasterFingerprint(device.toModel()));
  }

  @override
  Future<Result<String, LedgerFailure>> getXpub(
    LedgerDeviceEntity device, {
    required String derivationPath,
    required ScriptType scriptType,
  }) {
    return _guard(
      () => _datasource.getXpub(
        device.toModel(),
        derivationPath: derivationPath,
        scriptType: scriptType,
      ),
    );
  }

  @override
  Future<Result<String, LedgerFailure>> signPsbt(
    LedgerDeviceEntity device, {
    required String psbt,
    required String derivationPath,
    required ScriptType scriptType,
  }) {
    return _guard(
      () => _datasource.signPsbt(
        device.toModel(),
        psbt: psbt,
        derivationPath: derivationPath,
        scriptType: scriptType,
      ),
    );
  }

  @override
  Future<Result<bool, LedgerFailure>> verifyAddress(
    LedgerDeviceEntity device, {
    required String address,
    required String derivationPath,
    required ScriptType scriptType,
  }) {
    return _guard(
      () => _datasource.verifyAddress(
        device.toModel(),
        address: address,
        derivationPath: derivationPath,
        scriptType: scriptType,
      ),
    );
  }

  @override
  Future<Result<void, LedgerFailure>> disconnectConnection(
    LedgerDeviceEntity device,
  ) => _guard(
    () => _datasource.disconnectConnection(device.toModel()),
    isCleanup: true,
  );

  @override
  Future<Result<void, LedgerFailure>> dispose() =>
      _guard(() => _datasource.dispose(), isCleanup: true);

  /// The single try/catch boundary for the ledger domain. Runs [op], logs the
  /// raw reason, and maps every thrown thing to a typed [LedgerFailure] — no
  /// raw text ever escapes this method. The `on ...LedgerException` arms map
  /// the datasource's semantic signals; the trailing `catch` interprets raw
  /// device/SDK errors (APDU codes) and falls back to a generic failure.
  Future<Result<T, LedgerFailure>> _guard<T>(
    Future<T> Function() op, {
    bool isCleanup = false,
  }) async {
    try {
      return Ok(await op());
    } on PermissionDeniedLedgerException {
      return const Err(LedgerPermissionDeniedFailure());
    } on DeviceNotFoundLedgerException {
      return const Err(LedgerDeviceNotFoundFailure());
    } on NoActiveConnectionLedgerException {
      return const Err(LedgerNoConnectionFailure());
    } on DeviceMismatchLedgerException {
      return const Err(LedgerDeviceMismatchFailure());
    } on InvalidMagicBytesLedgerException {
      return const Err(LedgerInvalidPsbtFailure());
    } on ConnectionTypeNotInitializedLedgerException {
      return const Err(
        LedgerNoConnectionFailure('connection type not initialized'),
      );
    } catch (e, st) {
      final failure = _interpretRawError(e);
      if (isCleanup) {
        log.warning('Ledger cleanup failed', error: e, trace: st);
      } else if (failure is LedgerUnexpectedFailure) {
        log.severe(message: 'Ledger operation failed', error: e, trace: st);
      } else {
        log.warning('Ledger operation failed', error: e, trace: st);
      }
      return Err(failure);
    }
  }

  /// Interprets a raw device/SDK error string into a typed failure by APDU
  /// status word. The raw reason is carried in [Failure.logMessage] for logs
  /// only; it is never rendered by the UI.
  LedgerFailure _interpretRawError(Object error) {
    final raw = error.toString();

    // The Ledger SDK reports a busy device as free text, not an APDU code.
    if (_deviceBusyPattern.hasMatch(raw)) return LedgerDeviceBusyFailure(raw);

    final code = _extractApduCode(raw);
    if (code != null) {
      if (code == '6985') return LedgerRejectedByUserFailure(raw);
      if (code == '5515') return LedgerDeviceLockedFailure(raw);
      const appNotOpenCodes = {'6e01', '6a87', '6d02', '6511', '6e00'};
      if (appNotOpenCodes.contains(code)) {
        return LedgerBitcoinAppNotOpenFailure(raw);
      }
    }
    return LedgerUnexpectedFailure(raw);
  }

  static final RegExp _deviceBusyPattern = RegExp(
    r'no other program|another program|already (in use|open)|'
    r'communicating with the ledger',
    caseSensitive: false,
  );

  /// Extracts a normalized (lowercase, no `0x`) 4-hex-digit APDU status word.
  String? _extractApduCode(String error) {
    final match = _apduCodePattern.firstMatch(error);
    if (match == null) return null;
    return (match.group(1) ?? match.group(2))?.toLowerCase();
  }

  /// Matches an APDU status word only when it is unambiguously labelled: either
  /// hex-prefixed (`0x6985`) or introduced by a status-word keyword (`sw=6985`,
  /// `status word 6985`, `apdu: 6985`). A bare 4-character run is deliberately
  /// NOT matched — `timeout after 6985 ms`, or an incidental slice of a txid,
  /// would otherwise be read as "rejected by user" and show the user a
  /// confidently wrong reason.
  static final RegExp _apduCodePattern = RegExp(
    r'0x([0-9a-f]{4})\b'
    r'|\b(?:sw|status(?:\s*word)?|apdu(?:\s*(?:code|status))?|code)'
    r'\s*[:=]?\s*(?:0x)?([0-9a-f]{4})\b',
    caseSensitive: false,
  );
}
