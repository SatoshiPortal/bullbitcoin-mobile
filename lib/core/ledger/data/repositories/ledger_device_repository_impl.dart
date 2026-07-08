import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/ledger/data/datasources/ledger_device_datasource.dart';
import 'package:bb_mobile/core/ledger/data/models/ledger_device_model.dart';
import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/errors/ledger_exception.dart';
import 'package:bb_mobile/core/ledger/domain/errors/ledger_failure.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:satoshifier/satoshifier.dart' hide Network;

class LedgerDeviceRepositoryImpl implements LedgerDeviceRepository {
  final LedgerDeviceDatasource _datasource;
  final SettingsRepository _settingsRepository;

  LedgerDeviceRepositoryImpl({
    required this._datasource,
    required this._settingsRepository,
  });

  @override
  Future<Result<List<LedgerDeviceEntity>, LedgerFailure>> scanDevices({
    SignerDeviceEntity? deviceType,
  }) {
    return _guard(() async {
      final models = await _datasource.scanDevices(deviceType: deviceType);
      return models.map((model) => model.toEntity()).toList();
    });
  }

  @override
  Future<Result<Null, LedgerFailure>> connectDevice(LedgerDeviceEntity device) {
    return _guard(() async {
      await _datasource.connectDevice(device.toModel());
      return null;
    });
  }

  @override
  Future<Result<WatchOnlyWalletEntity, LedgerFailure>> getWatchOnlyWallet(
    LedgerDeviceEntity device, {
    required String label,
    ScriptType scriptType = ScriptType.bip84,
    int account = 0,
  }) async {
    final Satoshifier watchOnly;
    switch (await _guard(() async {
      final settings = await _settingsRepository.fetch();
      final network = Network.fromEnvironment(
        isTestnet: settings.environment.isTestnet,
        isLiquid: false,
      );

      final derivationPath =
          "m/${scriptType.purpose}'/${network.coinType}'/$account'";

      final model = device.toModel();
      final masterFingerprint = await _datasource.getMasterFingerprint(model);
      final xpub = await _datasource.getXpub(
        model,
        derivationPath: derivationPath,
        scriptType: scriptType,
      );

      final descriptor = Descriptor.fromStrings(
        fingerprint: masterFingerprint,
        path: derivationPath,
        xpub: xpub,
      );

      return Satoshifier.watchOnlyDescriptor(descriptor: descriptor);
    })) {
      case Ok(:final value):
        watchOnly = value;
      case Err(:final failure):
        return Err(failure);
    }

    if (watchOnly is! WatchOnlyDescriptor) {
      log.severe(
        message: 'Unexpected Ledger descriptor type',
        error: 'got ${watchOnly.runtimeType}',
        trace: StackTrace.current,
      );
      return const Err(LedgerUnexpectedFailure('unexpected descriptor type'));
    }

    return Ok(
      WatchOnlyWalletEntity.descriptor(
        watchOnlyDescriptor: watchOnly,
        signer: SignerEntity.remote,
        label: label,
        signerDevice: device.deviceType,
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
  Future<void> disconnectConnection(LedgerDeviceEntity device) async {
    try {
      await _datasource.disconnectConnection(device.toModel());
    } catch (e) {
      log.warning('Error disconnecting Ledger device', error: e);
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _datasource.dispose();
    } catch (e) {
      log.warning('Error disposing Ledger datasource', error: e);
    }
  }

  /// The single try/catch boundary for the ledger domain. Runs [op], logs the
  /// raw reason, and maps every thrown thing to a typed [LedgerFailure] — no
  /// raw text ever escapes this method. The `on ...LedgerException` arms map
  /// the datasource's semantic signals; the trailing `catch` interprets raw
  /// device/SDK errors (APDU codes) and falls back to a generic failure.
  Future<Result<T, LedgerFailure>> _guard<T>(Future<T> Function() op) async {
    try {
      return Ok(await op());
    } on PermissionDeniedLedgerException {
      return const Err(LedgerPermissionDeniedFailure());
    } on NoDevicesFoundLedgerException {
      return const Err(LedgerNoDevicesFoundFailure());
    } on MultipleDevicesFoundLedgerException {
      return const Err(LedgerMultipleDevicesFoundFailure());
    } on DeviceNotFoundLedgerException {
      return const Err(LedgerDeviceNotFoundFailure());
    } on NoActiveConnectionLedgerException {
      return const Err(LedgerNoActiveConnectionFailure());
    } on DeviceMismatchLedgerException {
      return const Err(LedgerDeviceMismatchFailure());
    } on InvalidMagicBytesLedgerException {
      return const Err(LedgerInvalidPsbtFailure());
    } on ConnectionTypeNotInitializedLedgerException {
      // Internal wiring bug — never a meaningful message for the user.
      return const Err(
        LedgerUnexpectedFailure('connection type not initialized'),
      );
    } catch (e, st) {
      final failure = _interpretRawError(e);
      if (failure is LedgerUnexpectedFailure) {
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
    final code = _extractApduCode(raw);
    if (code != null) {
      if (code.contains('6985')) return LedgerRejectedByUserFailure(raw);
      if (code.contains('5515')) return LedgerDeviceLockedFailure(raw);
      const appNotOpenCodes = ['6e01', '6a87', '6d02', '6511', '6e00'];
      if (appNotOpenCodes.any(code.contains)) {
        return LedgerBitcoinAppNotOpenFailure(raw);
      }
    }
    return LedgerUnexpectedFailure(raw);
  }

  String? _extractApduCode(String error) {
    final patterns = [
      RegExp(r'(?:0x\S*?|[0-9a-f]{4})(?= )'),
      RegExp('Exception:\\s*([0-9a-f]{4})'),
      RegExp('[0-9a-f]{4}'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(error);
      if (match != null) {
        return match
            .group(0)
            ?.replaceAll('0x', '')
            .replaceAll('Exception: ', '');
      }
    }
    return null;
  }
}
