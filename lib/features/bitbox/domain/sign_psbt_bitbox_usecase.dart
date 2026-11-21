import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core/bitbox/domain/errors/bitbox_failure.dart';
import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:primitives/primitives.dart' show Err, Result, ScriptType;
import 'package:meta/meta.dart';

class SignPsbtBitBoxUsecase {
  final BitBoxDeviceRepository _repository;

  SignPsbtBitBoxUsecase({required this._repository});

  @useResult
  Future<Result<String, BitBoxFailure>> execute(
    BitBoxDeviceEntity device, {
    required NetworkEnv network,
    required String psbt,
    required String derivationPath,
    required ScriptType scriptType,
  }) async {
    if (network != NetworkEnv.mainnet && network != NetworkEnv.testnet) {
      return const Err(InvalidParametersBitBoxFailure('unsupported network'));
    }
    final isTestnet = network == NetworkEnv.testnet;

    return _repository.signPsbt(
      device,
      psbt: psbt,
      derivationPath: derivationPath,
      scriptType: scriptType,
      isTestnet: isTestnet,
    );
  }
}
