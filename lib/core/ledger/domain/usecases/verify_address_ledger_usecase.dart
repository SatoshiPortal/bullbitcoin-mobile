import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class VerifyAddressLedgerUsecase {
  final LedgerDeviceRepository _repository;

  VerifyAddressLedgerUsecase({required LedgerDeviceRepository repository})
    : _repository = repository;

  Future<bool> execute({
    required LedgerDeviceEntity device,
    required String address,
    required String derivationPath,
    required ScriptType scriptType,
  }) async {
    return await _repository.verifyAddress(
      device,
      address: address,
      derivationPath: derivationPath,
      scriptType: scriptType,
    );
  }
}
