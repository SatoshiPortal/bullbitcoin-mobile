import 'package:bb_mobile/core_deprecated/entities/signer_device_entity.dart';
import 'package:bb_mobile/core_deprecated/ledger/data/datasources/ledger_device_datasource.dart';
import 'package:bb_mobile/core_deprecated/ledger/data/models/ledger_device_model.dart';
import 'package:bb_mobile/core_deprecated/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core_deprecated/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/entities/wallet.dart';

class LedgerDeviceRepositoryImpl implements LedgerDeviceRepository {
  final LedgerDeviceDatasource _datasource;

  LedgerDeviceRepositoryImpl({required LedgerDeviceDatasource datasource})
      : _datasource = datasource;

  @override
  Future<List<LedgerDeviceEntity>> scanDevices({SignerDeviceEntity? deviceType}) async {
    final models = await _datasource.scanDevices(
      deviceType: deviceType,
    );
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<void> connectDevice(LedgerDeviceEntity device) async {
    final model = device.toModel();
    await _datasource.connectDevice(model);
  }

  @override
  Future<String> getXpub(
    LedgerDeviceEntity device, {
    required String derivationPath,
    required ScriptType scriptType,
  }) async {
    final model = device.toModel();
    return await _datasource.getXpub(
      model,
      derivationPath: derivationPath,
      scriptType: scriptType,
    );
  }

  @override
  Future<String> getMasterFingerprint(LedgerDeviceEntity device) async {
    final model = device.toModel();
    return await _datasource.getMasterFingerprint(model);
  }

  @override
  Future<String> signPsbt(
    LedgerDeviceEntity device, {
    required String psbt,
    required String derivationPath,
    required ScriptType scriptType,
  }) async {
    final model = device.toModel();
    return await _datasource.signPsbt(
      model,
      psbt: psbt,
      derivationPath: derivationPath,
      scriptType: scriptType,
    );
  }

  @override
  Future<bool> verifyAddress(
    LedgerDeviceEntity device, {
    required String address,
    required String derivationPath,
    required ScriptType scriptType,
  }) async {
    final model = device.toModel();
    return await _datasource.verifyAddress(
      model,
      address: address,
      derivationPath: derivationPath,
      scriptType: scriptType,
    );
  }

  @override
  Future<void> disconnectConnection(LedgerDeviceEntity device) async {
    final model = device.toModel();
    await _datasource.disconnectConnection(model);
  }

  @override
  Future<void> dispose() async {
    await _datasource.dispose();
  }
}
