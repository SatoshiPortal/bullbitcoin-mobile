import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_policy_registration_name.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_signer_device_port.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:meta/meta.dart';

class UpdateBullVaultRegistrationNameUsecase {
  final WalletSignerDevicePort _walletSignerDevicePort;

  const UpdateBullVaultRegistrationNameUsecase(this._walletSignerDevicePort);

  @useResult
  Future<Result<Wallet, BullVaultFailure>> execute({
    required Wallet wallet,
    required String signerId,
    required String name,
  }) async {
    final matching = wallet.signers.where((signer) => signer.id == signerId);
    if (matching.length != 1 || matching.single.signerDevice == null) {
      return const Err(BullVaultInvalidSignerFailure());
    }
    try {
      final validated = WalletPolicyRegistrationName.validate(
        name,
        matching.single.signerDevice!,
      );
      return Ok(
        await _walletSignerDevicePort.updateSignerRegistrationName(
          walletId: wallet.id,
          signerId: signerId,
          registrationName: validated,
        ),
      );
    } on ArgumentError {
      return const Err(BullVaultInvalidSignerFailure());
    } on Exception catch (error) {
      return Err(BullVaultCreationFailure(error.runtimeType.toString()));
    }
  }
}
