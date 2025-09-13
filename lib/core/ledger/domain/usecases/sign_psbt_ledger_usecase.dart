import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';

class SignPsbtLedgerUsecase {
  final LedgerDeviceRepository _repository;

  SignPsbtLedgerUsecase({
    required LedgerDeviceRepository repository,
  }) : _repository = repository;

  Future<String> execute(
    LedgerDeviceEntity device, {
    required String psbt,
    required String derivationPath,
  }) async {
    return await _repository.signPsbt(
      device,
      psbt: psbt,
      derivationPath: derivationPath,
    );
  }
}
