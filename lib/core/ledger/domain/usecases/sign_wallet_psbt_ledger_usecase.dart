import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/ledger_failure.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class SignWalletPsbtLedgerUsecase {
  final LedgerDeviceRepository _repository;

  const SignWalletPsbtLedgerUsecase({required this._repository});

  Future<Result<String, LedgerFailure>> execute({
    required LedgerDeviceEntity device,
    required Wallet wallet,
    required String signerId,
    required String psbt,
  }) => _repository.signWalletPsbt(
    device,
    wallet: wallet,
    signerId: signerId,
    psbt: psbt,
  );
}
