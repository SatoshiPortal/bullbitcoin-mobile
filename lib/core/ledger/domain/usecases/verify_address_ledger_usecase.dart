import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/ledger_failure.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:primitives/primitives.dart'
    show Err, NetworkEnv, Ok, Result, ScriptType;
import 'package:meta/meta.dart';

class VerifyAddressLedgerUsecase {
  final LedgerDeviceRepository _repository;

  VerifyAddressLedgerUsecase({required this._repository});

  @useResult
  Future<Result<bool, LedgerFailure>> execute({
    required LedgerDeviceEntity device,
    required String address,
    required NetworkEnv network,
    required String derivationPath,
    required ScriptType scriptType,
  }) async {
    if (network != NetworkEnv.mainnet && network != NetworkEnv.testnet) {
      return const Err(LedgerUnexpectedFailure('unsupported network'));
    }
    final result = await _repository.verifyAddress(
      device,
      address: address,
      derivationPath: derivationPath,
      scriptType: scriptType,
    );
    return switch (result) {
      Ok(value: false) => const Err(
        LedgerUnexpectedFailure(
          'device address does not match requested address',
        ),
      ),
      _ => result,
    };
  }
}
