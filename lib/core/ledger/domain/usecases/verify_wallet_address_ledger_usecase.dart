import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/ledger_failure.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class VerifyWalletAddressLedgerUsecase {
  final LedgerDeviceRepository _repository;

  const VerifyWalletAddressLedgerUsecase({required this._repository});

  Future<Result<bool, LedgerFailure>> execute({
    required LedgerDeviceEntity device,
    required Wallet wallet,
    required String address,
    required BitcoinPolicyKeychain keychain,
    required int index,
  }) => _repository.verifyWalletAddress(
    device,
    wallet: wallet,
    address: address,
    keychain: keychain,
    index: index,
  );
}
