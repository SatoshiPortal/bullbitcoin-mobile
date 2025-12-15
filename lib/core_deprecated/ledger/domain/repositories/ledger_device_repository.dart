import 'package:bb_mobile/core_deprecated/entities/signer_device_entity.dart';
import 'package:bb_mobile/core_deprecated/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/entities/wallet.dart';

abstract class LedgerDeviceRepository {
  Future<List<LedgerDeviceEntity>> scanDevices({
    SignerDeviceEntity? deviceType,
  });

  Future<void> connectDevice(LedgerDeviceEntity device);

  Future<String> getXpub(
    LedgerDeviceEntity device, {
    required String derivationPath,
    required ScriptType scriptType,
  });

  Future<String> getMasterFingerprint(LedgerDeviceEntity device);

  Future<String> signPsbt(
    LedgerDeviceEntity device, {
    required String psbt,
    required String derivationPath,
    required ScriptType scriptType,
  });

  Future<bool> verifyAddress(
    LedgerDeviceEntity device, {
    required String address,
    required String derivationPath,
    required ScriptType scriptType,
  });

  Future<void> disconnectConnection(LedgerDeviceEntity device);
  Future<void> dispose();
}
