import 'package:bb_mobile/features/ledger/domain/signer_account.dart';
import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/ledger_failure.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result, ScriptType;
import 'package:meta/meta.dart';

class ReadLedgerAccountUsecase {
  final LedgerDeviceRepository _repository;

  ReadLedgerAccountUsecase({required this._repository});

  @useResult
  Future<Result<SignerAccount, LedgerFailure>> execute({
    required NetworkEnv network,
    required LedgerDeviceEntity device,
    ScriptType scriptType = ScriptType.bip84,
    int account = 0,
  }) async {
    if (network != NetworkEnv.mainnet && network != NetworkEnv.testnet) {
      return const Err(LedgerUnexpectedFailure('unsupported network'));
    }
    final coinType = network == NetworkEnv.mainnet ? 0 : 1;
    final derivationPath = "m/${scriptType.purpose}'/$coinType'/$account'";

    final String masterFingerprint;
    switch (await _repository.getMasterFingerprint(device)) {
      case Ok(:final value):
        masterFingerprint = value;
      case Err(:final failure):
        return Err(failure);
    }

    final String xpub;
    switch (await _repository.getXpub(
      device,
      derivationPath: derivationPath,
      scriptType: scriptType,
    )) {
      case Ok(:final value):
        xpub = value;
      case Err(:final failure):
        return Err(failure);
    }

    return Ok(
      SignerAccount(
        masterFingerprint: masterFingerprint,
        derivationPath: derivationPath,
        xpub: xpub,
        scriptType: scriptType,
        device: device.deviceType,
        network: network,
      ),
    );
  }
}
