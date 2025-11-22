import 'package:bb_mobile/core/bitbox/data/datasources/bitbox_device_datasource.dart';
import 'package:bb_mobile/core/bitbox/data/models/bitbox_device_model.dart';
import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class BitBoxDeviceRepositoryImpl implements BitBoxDeviceRepository {
  final BitBoxDeviceDatasource _datasource;

  BitBoxDeviceRepositoryImpl({required BitBoxDeviceDatasource datasource})
      : _datasource = datasource;

  @override
  Future<List<BitBoxDeviceEntity>> scanDevices() async {
    final models = await _datasource.scanDevices();
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<void> connectDevice(BitBoxDeviceEntity device) async {
    final model = device.toModel();
    await _datasource.connectDevice(model);
  }

  @override
  Future<String> unlockDevice(BitBoxDeviceEntity device) async {
    final model = device.toModel();
    return await _datasource.unlockDevice(model);
  }

  @override
  Future<String> pairDevice(BitBoxDeviceEntity device) async {
    final model = device.toModel();
    return await _datasource.pairDevice(model);
  }

  @override
  Future<String> getXpub(
    BitBoxDeviceEntity device, {
    required String derivationPath,
    required ScriptType scriptType,
    required bool isTestnet,
  }) async {
    final model = device.toModel();
    return await _datasource.getXpub(
      model,
      derivationPath: derivationPath,
      scriptType: scriptType,
      isTestnet: isTestnet,
    );
  }

  @override
  Future<String> getMasterFingerprint(BitBoxDeviceEntity device) async {
    final model = device.toModel();
    return await _datasource.getMasterFingerprint(model);
  }

  @override
  Future<String> signPsbt(
    BitBoxDeviceEntity device, {
    required String psbt,
    required String derivationPath,
    required ScriptType scriptType,
    required bool isTestnet,
  }) async {
    final model = device.toModel();
    return await _datasource.signPsbt(
      model,
      psbt: psbt,
      derivationPath: derivationPath,
      scriptType: scriptType,
      isTestnet: isTestnet,
    );
  }

  @override
  Future<bool> verifyAddress(
    BitBoxDeviceEntity device, {
    required String address,
    required String derivationPath,
    required ScriptType scriptType,
    required bool isTestnet,
  }) async {
    final model = device.toModel();
    return await _datasource.verifyAddress(
      model,
      address: address,
      derivationPath: derivationPath,
      scriptType: scriptType,
      isTestnet: isTestnet,
    );
  }

  @override
  Future<void> disconnectConnection(BitBoxDeviceEntity device) async {
    final model = device.toModel();
    await _datasource.disconnectConnection(model);
  }

  @override
  Future<void> dispose() async {
    await _datasource.dispose();
  }
}
