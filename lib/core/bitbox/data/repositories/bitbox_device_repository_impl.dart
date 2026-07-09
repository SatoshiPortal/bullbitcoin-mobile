import 'package:bb_mobile/core/bitbox/data/datasources/bitbox_device_datasource.dart';
import 'package:bb_mobile/core/bitbox/data/models/bitbox_device_model.dart';
import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core/bitbox/domain/errors/bitbox_failure.dart';
import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class BitBoxDeviceRepositoryImpl implements BitBoxDeviceRepository {
  final BitBoxDeviceDatasource _datasource;

  BitBoxDeviceRepositoryImpl({required this._datasource});

  /// [isCleanup] downgrades the log to `warning`: a failed teardown
  /// (disconnect/dispose) is not user-facing and shouldn't page as `severe`.
  Future<Result<T, BitBoxFailure>> _guard<T>(
    Future<T> Function() run, {
    bool isCleanup = false,
  }) async {
    try {
      return Ok(await run());
    } on BitBoxFailure catch (f) {
      return Err(f);
    } catch (e, st) {
      if (isCleanup) {
        log.warning('BitBox cleanup failed', error: e, trace: st);
      } else {
        log.severe(message: 'BitBox operation failed', error: e, trace: st);
      }
      return Err(BitBoxUnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<BitBoxDeviceEntity>, BitBoxFailure>> scanDevices() =>
      _guard(() async {
        final models = await _datasource.scanDevices();
        return models.map((model) => model.toEntity()).toList();
      });

  @override
  Future<Result<void, BitBoxFailure>> connectDevice(
    BitBoxDeviceEntity device,
  ) => _guard(() => _datasource.connectDevice(device.toModel()));

  @override
  Future<Result<String, BitBoxFailure>> unlockDevice(
    BitBoxDeviceEntity device,
  ) => _guard(() => _datasource.unlockDevice(device.toModel()));

  @override
  Future<Result<String, BitBoxFailure>> pairDevice(BitBoxDeviceEntity device) =>
      _guard(() => _datasource.pairDevice(device.toModel()));

  @override
  Future<Result<String, BitBoxFailure>> getXpub(
    BitBoxDeviceEntity device, {
    required String derivationPath,
    required ScriptType scriptType,
    required bool isTestnet,
  }) => _guard(
    () => _datasource.getXpub(
      device.toModel(),
      derivationPath: derivationPath,
      scriptType: scriptType,
      isTestnet: isTestnet,
    ),
  );

  @override
  Future<Result<String, BitBoxFailure>> getMasterFingerprint(
    BitBoxDeviceEntity device,
  ) => _guard(() => _datasource.getMasterFingerprint(device.toModel()));

  @override
  Future<Result<String, BitBoxFailure>> signPsbt(
    BitBoxDeviceEntity device, {
    required String psbt,
    required String derivationPath,
    required ScriptType scriptType,
    required bool isTestnet,
  }) => _guard(
    () => _datasource.signPsbt(
      device.toModel(),
      psbt: psbt,
      derivationPath: derivationPath,
      scriptType: scriptType,
      isTestnet: isTestnet,
    ),
  );

  @override
  Future<Result<bool, BitBoxFailure>> verifyAddress(
    BitBoxDeviceEntity device, {
    required String address,
    required String derivationPath,
    required ScriptType scriptType,
    required bool isTestnet,
  }) => _guard(
    () => _datasource.verifyAddress(
      device.toModel(),
      address: address,
      derivationPath: derivationPath,
      scriptType: scriptType,
      isTestnet: isTestnet,
    ),
  );

  @override
  Future<Result<void, BitBoxFailure>> disconnectConnection(
    BitBoxDeviceEntity device,
  ) => _guard(
    () => _datasource.disconnectConnection(device.toModel()),
    isCleanup: true,
  );

  @override
  Future<Result<void, BitBoxFailure>> dispose() =>
      _guard(() => _datasource.dispose(), isCleanup: true);
}
