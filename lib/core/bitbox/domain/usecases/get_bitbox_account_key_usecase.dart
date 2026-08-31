import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core/bitbox/domain/errors/bitbox_failure.dart';
import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:bb_mobile/core/utils/bip48_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:meta/meta.dart';

final class GetBitBoxAccountKeyUsecase {
  final BitBoxDeviceRepository _repository;

  const GetBitBoxAccountKeyUsecase(this._repository);

  @useResult
  Future<Result<String, BitBoxFailure>> execute({
    required BitBoxDeviceEntity device,
    required String derivationPath,
    required bool isTestnet,
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
      isTestnet: isTestnet,
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
