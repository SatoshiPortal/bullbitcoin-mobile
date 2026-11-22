import 'package:signers/src/ledger_flow/domain/signer_account.dart';
import 'package:primitives/primitives.dart'
    show Err, NetworkEnv, Ok, Result, ScriptType;
import 'package:signers/src/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:signers/src/bitbox/domain/errors/bitbox_failure.dart';
import 'package:signers/src/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:signers/src/signer_device.dart';
import 'package:meta/meta.dart';

class ReadBitBoxAccountUsecase {
  final BitBoxDeviceRepository _repository;

  ReadBitBoxAccountUsecase({required this._repository});

  @useResult
  Future<Result<SignerAccount, BitBoxFailure>> execute({
    required NetworkEnv network,
    required BitBoxDeviceEntity device,
    ScriptType scriptType = ScriptType.bip84,
    int account = 0,
  }) async {
    if (network != NetworkEnv.mainnet && network != NetworkEnv.testnet) {
      return const Err(InvalidParametersBitBoxFailure('unsupported network'));
    }
    final isTestnet = network == NetworkEnv.testnet;
    final coinType = network == NetworkEnv.mainnet ? 0 : 1;
    final derivationPath = "m/${scriptType.purpose}'/$coinType'/$account'";

    final String masterFingerprint;
    switch (await _repository.getMasterFingerprint(device)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        masterFingerprint = value;
    }

    final String xpub;
    switch (await _repository.getXpub(
      device,
      derivationPath: derivationPath,
      scriptType: scriptType,
      isTestnet: isTestnet,
    )) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        xpub = value;
    }

    return Ok(
      SignerAccount(
        masterFingerprint: masterFingerprint,
        derivationPath: derivationPath,
        xpub: xpub,
        scriptType: scriptType,
        device: SignerDevice.bitbox02,
        network: network,
      ),
    );
  }
}
