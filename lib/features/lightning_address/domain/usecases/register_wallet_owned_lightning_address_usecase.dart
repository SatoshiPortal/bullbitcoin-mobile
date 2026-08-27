import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_failure.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_wallet.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_wallet_registration.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/prepare_lightning_address_wallet_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/register_lightning_address_usecase.dart';

final class RegisterWalletOwnedLightningAddressUsecase {
  final PrepareLightningAddressWalletUsecase _prepareWallet;
  final RegisterLightningAddressUsecase _register;

  const RegisterWalletOwnedLightningAddressUsecase(
    this._prepareWallet,
    this._register,
  );

  Future<
    Result<WalletOwnedLightningAddressRegistration, LightningAddressFailure>
  >
  execute({required String nym}) => _execute(nym: nym, recordAsRecovery: false);

  Future<
    Result<WalletOwnedLightningAddressRegistration, LightningAddressFailure>
  >
  executeFromRecovery({required String nym}) =>
      _execute(nym: nym, recordAsRecovery: true);

  Future<
    Result<WalletOwnedLightningAddressRegistration, LightningAddressFailure>
  >
  _execute({required String nym, required bool recordAsRecovery}) async {
    final preparedResult = await _prepareWallet.execute(
      recordAsRecovery: recordAsRecovery,
    );
    final PreparedLightningAddressWallet prepared;
    switch (preparedResult) {
      case Ok(:final value):
        prepared = value;
      case Err(:final failure):
        return Err(
          failure.atPhase(LightningAddressFailurePhase.localPreparation),
        );
    }

    final registration = await _register.execute(
      nym: nym,
      ctDescriptor: prepared.ctDescriptor,
    );
    return switch (registration) {
      Ok(:final value) => Ok(
        WalletOwnedLightningAddressRegistration(
          registration: value,
          walletId: prepared.walletId,
          walletCreated: prepared.created,
        ),
      ),
      Err(:final failure) => Err(
        failure.atPhase(LightningAddressFailurePhase.registrationSubmission),
      ),
    };
  }
}
