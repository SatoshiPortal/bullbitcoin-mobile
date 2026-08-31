import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/ledger_failure.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:bb_mobile/core/utils/bip48_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:meta/meta.dart';

final class GetLedgerAccountKeyUsecase {
  final LedgerDeviceRepository _repository;

  const GetLedgerAccountKeyUsecase(this._repository);

  @useResult
  Future<Result<String, LedgerFailure>> execute({
    required LedgerDeviceEntity device,
    required String derivationPath,
  }) async {
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
      scriptType: ScriptType.bip44,
    )) {
      case Ok(:final value):
        xpub = value;
      case Err(:final failure):
        return Err(failure);
    }

    return Ok(
      Bip48Derivation.accountKeyExpression(
        masterFingerprint: masterFingerprint,
        derivationPath: derivationPath,
        xpub: xpub,
      ),
    );
  }
}
