import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/ledger_failure.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:primitives/primitives.dart'
    show Err, NetworkEnv, Result, ScriptType;
import 'package:meta/meta.dart';

class SignPsbtLedgerUsecase {
  final LedgerDeviceRepository _repository;

  SignPsbtLedgerUsecase({required this._repository});

  @useResult
  Future<Result<String, LedgerFailure>> execute(
    LedgerDeviceEntity device, {
    required String psbt,
    required NetworkEnv network,
    required String derivationPath,
    required ScriptType scriptType,
  }) async {
    if (network != NetworkEnv.mainnet && network != NetworkEnv.testnet) {
      return const Err(LedgerUnexpectedFailure('unsupported network'));
    }
    return _repository.signPsbt(
      device,
      psbt: psbt,
      derivationPath: derivationPath,
      scriptType: scriptType,
    );
  }
}
