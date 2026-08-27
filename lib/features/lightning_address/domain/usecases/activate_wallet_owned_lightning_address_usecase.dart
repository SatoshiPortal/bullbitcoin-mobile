import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_failure.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/register_wallet_owned_lightning_address_usecase.dart';

class ActivateWalletOwnedLightningAddressUsecase {
  final RegisterWalletOwnedLightningAddressUsecase _registerWalletOwned;

  const ActivateWalletOwnedLightningAddressUsecase(this._registerWalletOwned);

  Future<Result<LightningAddressRegistration, LightningAddressFailure>>
  execute({required String nym}) async => (await _registerWalletOwned.execute(
    nym: nym,
  )).map((registration) => registration.registration);
}
