import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/ledger_failure.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:meta/meta.dart';

class SignPsbtLedgerUsecase {
  final LedgerDeviceRepository _repository;

  SignPsbtLedgerUsecase({required this._repository});

  @useResult
  Future<Result<String, LedgerFailure>> execute(
    LedgerDeviceEntity device, {
    required String psbt,
    required String derivationPath,
    required ScriptType scriptType,
  }) {
    return _repository.signPsbt(
      device,
      psbt: psbt,
      derivationPath: derivationPath,
      scriptType: scriptType,
    );
  }
}
