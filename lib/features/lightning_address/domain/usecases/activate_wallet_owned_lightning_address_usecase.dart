import 'package:bb_mobile/features/lightning_address/domain/lightning_address_error.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/register_wallet_owned_lightning_address_usecase.dart';

class ActivateWalletOwnedLightningAddressUsecase {
  final RegisterWalletOwnedLightningAddressUsecase _registerWalletOwned;

  const ActivateWalletOwnedLightningAddressUsecase(this._registerWalletOwned);

  Future<LightningAddressRegistration> execute({required String nym}) async {
    try {
      final result = await _registerWalletOwned.execute(nym: nym);
      return result.registration;
    } on WalletOwnedLightningAddressRegistrationException catch (e) {
      throw WalletOwnedLightningAddressActivationException.fromRegistration(e);
    }
  }
}
