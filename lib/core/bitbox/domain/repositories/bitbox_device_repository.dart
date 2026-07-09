import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core/bitbox/domain/errors/bitbox_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:meta/meta.dart';

abstract class BitBoxDeviceRepository {
  @useResult
  Future<Result<List<BitBoxDeviceEntity>, BitBoxFailure>> scanDevices();

  @useResult
  Future<Result<void, BitBoxFailure>> connectDevice(BitBoxDeviceEntity device);

  @useResult
  Future<Result<String, BitBoxFailure>> unlockDevice(BitBoxDeviceEntity device);

  @useResult
  Future<Result<String, BitBoxFailure>> pairDevice(BitBoxDeviceEntity device);

  @useResult
  Future<Result<String, BitBoxFailure>> getXpub(
    BitBoxDeviceEntity device, {
    required String derivationPath,
    required ScriptType scriptType,
    required bool isTestnet,
  });

  @useResult
  Future<Result<String, BitBoxFailure>> getMasterFingerprint(
    BitBoxDeviceEntity device,
  );

  @useResult
  Future<Result<String, BitBoxFailure>> signPsbt(
    BitBoxDeviceEntity device, {
    required String psbt,
    required String derivationPath,
    required ScriptType scriptType,
    required bool isTestnet,
  });

  @useResult
  Future<Result<bool, BitBoxFailure>> verifyAddress(
    BitBoxDeviceEntity device, {
    required String address,
    required String derivationPath,
    required ScriptType scriptType,
    required bool isTestnet,
  });

  Future<Result<void, BitBoxFailure>> disconnectConnection(
    BitBoxDeviceEntity device,
  );
  Future<Result<void, BitBoxFailure>> dispose();
}
