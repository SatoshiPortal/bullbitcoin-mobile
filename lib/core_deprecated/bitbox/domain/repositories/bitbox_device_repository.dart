import 'package:bb_mobile/core_deprecated/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/entities/wallet.dart';

abstract class BitBoxDeviceRepository {
  Future<List<BitBoxDeviceEntity>> scanDevices();

  Future<void> connectDevice(BitBoxDeviceEntity device);

  Future<String> unlockDevice(BitBoxDeviceEntity device);

  Future<String> pairDevice(BitBoxDeviceEntity device);

  Future<String> getXpub(
    BitBoxDeviceEntity device, {
    required String derivationPath,
    required ScriptType scriptType,
    required bool isTestnet,
  });

  Future<String> getMasterFingerprint(BitBoxDeviceEntity device);

  Future<String> signPsbt(
    BitBoxDeviceEntity device, {
    required String psbt,
    required String derivationPath,
    required ScriptType scriptType,
    required bool isTestnet,
  });

  Future<bool> verifyAddress(
    BitBoxDeviceEntity device, {
    required String address,
    required String derivationPath,
    required ScriptType scriptType,
    required bool isTestnet,
  });

  Future<void> disconnectConnection(BitBoxDeviceEntity device);
  Future<void> dispose();
}
