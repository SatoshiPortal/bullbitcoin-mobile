import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core/bitbox/domain/errors/bitbox_failure.dart';
import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:meta/meta.dart';

class SignWalletPsbtBitBoxUsecase {
  final BitBoxDeviceRepository _repository;

  const SignWalletPsbtBitBoxUsecase({required this._repository});

  @useResult
  Future<Result<String, BitBoxFailure>> execute({
    required BitBoxDeviceEntity device,
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
