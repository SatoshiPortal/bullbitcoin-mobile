import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';

abstract class LedgerDeviceRepository {
  Future<List<LedgerDeviceEntity>> scanDevices();

  Future<void> connectDevice(LedgerDeviceEntity device);

  Future<String> getXpub(
    LedgerDeviceEntity device, {
    required String derivationPath,
  });

  Future<String> getMasterFingerprint(LedgerDeviceEntity device);

  Future<String> signPsbt(
    LedgerDeviceEntity device, {
    required String psbt,
    required String derivationPath,
  });

  Future<bool> verifyAddress(
    LedgerDeviceEntity device, {
    required String address,
    required String derivationPath,
  });

  Future<void> disconnectConnection(LedgerDeviceEntity device);
  Future<void> dispose();
}
