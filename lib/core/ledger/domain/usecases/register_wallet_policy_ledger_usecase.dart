import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/ledger_failure.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:primitives/primitives.dart' show Result;
import 'package:bb_mobile/features/wallet/domain/wallet.dart';

class RegisterWalletPolicyLedgerUsecase {
  final LedgerDeviceRepository _repository;

  const RegisterWalletPolicyLedgerUsecase({required this._repository});

  Future<Result<void, LedgerFailure>> execute({
    required LedgerDeviceEntity device,
    required Wallet wallet,
    String? signerId,
  }) => _repository.registerWalletPolicy(
    device,
    wallet: wallet,
    signerId: signerId,
  );
}
