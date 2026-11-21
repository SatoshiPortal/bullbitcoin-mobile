import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core/bitbox/domain/errors/bitbox_failure.dart';
import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result, ScriptType;
import 'package:meta/meta.dart';

class VerifyAddressBitBoxUsecase {
  final BitBoxDeviceRepository _repository;

  VerifyAddressBitBoxUsecase({required this._repository});

  @useResult
  Future<Result<bool, BitBoxFailure>> execute({
    required BitBoxDeviceEntity device,
    required NetworkEnv network,
    required String address,
    required String derivationPath,
    required ScriptType scriptType,
  }) async {
    if (network != NetworkEnv.mainnet && network != NetworkEnv.testnet) {
      return const Err(InvalidParametersBitBoxFailure('unsupported network'));
    }
    final isTestnet = network == NetworkEnv.testnet;

    switch (await _repository.verifyAddress(
      device,
      address: address,
      derivationPath: derivationPath.replaceAll('h', "'"),
      scriptType: scriptType,
      isTestnet: isTestnet,
    )) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        return value
            ? const Ok(true)
            : const Err(InvalidResponseBitBoxFailure());
    }
  }
}
