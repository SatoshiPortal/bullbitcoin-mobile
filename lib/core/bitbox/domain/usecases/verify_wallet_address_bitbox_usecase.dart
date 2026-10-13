import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core/bitbox/domain/errors/bitbox_failure.dart';
import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:meta/meta.dart';

class VerifyWalletAddressBitBoxUsecase {
  final BitBoxDeviceRepository _repository;

  const VerifyWalletAddressBitBoxUsecase({required this._repository});

  @useResult
  Future<Result<bool, BitBoxFailure>> execute({
    required BitBoxDeviceEntity device,
    required Wallet wallet,
    required String address,
    required BitcoinPolicyKeychain keychain,
    required int index,
    String? signerId,
  }) => _repository.verifyWalletAddress(
    device,
    wallet: wallet,
    address: address,
    keychain: keychain,
    index: index,
    signerId: signerId,
  );
}
