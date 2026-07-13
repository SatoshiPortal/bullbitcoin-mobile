import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/errors/ledger_failure.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:meta/meta.dart';

class VerifyAddressLedgerUsecase {
  final LedgerDeviceRepository _repository;

  VerifyAddressLedgerUsecase({required this._repository});

  @useResult
  Future<Result<bool, LedgerFailure>> execute({
    required LedgerDeviceEntity device,
    required String address,
    required String derivationPath,
    required ScriptType scriptType,
  }) {
    return _repository.verifyAddress(
      device,
      address: address,
      derivationPath: derivationPath,
      scriptType: scriptType,
    );
  }
}
