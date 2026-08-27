import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_failure.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/delete_lightning_address_registration_usecase.dart';

final class DeactivateWalletOwnedLightningAddressUsecase {
  final DeleteLightningAddressRegistrationUsecase _delete;

  const DeactivateWalletOwnedLightningAddressUsecase(this._delete);

  Future<Result<void, LightningAddressFailure>> execute({
    required String nym,
  }) => _delete.execute(nym: nym);
}
