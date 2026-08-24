import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/ledger_failure.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class RegisterWalletPolicyLedgerUsecase {
  final LedgerDeviceRepository _repository;

  const RegisterWalletPolicyLedgerUsecase({required this._repository});

  Future<Result<void, LedgerFailure>> execute({
    required LedgerDeviceEntity device,
    required Wallet wallet,
  }) => _repository.registerWalletPolicy(device, wallet: wallet);
}
