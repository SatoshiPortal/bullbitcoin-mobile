import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_failure.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lookup_lightning_address_registration_usecase.dart';

final class LookupWalletOwnedLightningAddressRegistrationUsecase {
  final LookupLightningAddressRegistrationUsecase _lookupRegistration;

  const LookupWalletOwnedLightningAddressRegistrationUsecase(
    this._lookupRegistration,
  );

  Future<Result<LightningAddressStatus, LightningAddressFailure>> execute() =>
      _lookupRegistration.execute();
}
