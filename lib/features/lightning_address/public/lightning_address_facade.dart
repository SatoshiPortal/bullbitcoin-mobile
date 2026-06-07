import 'package:bb_mobile/features/lightning_address/application/usecases/delete_lightning_address_registration_usecase.dart';
import 'package:bb_mobile/features/lightning_address/application/usecases/lookup_lightning_address_registration_usecase.dart';
import 'package:bb_mobile/features/lightning_address/application/usecases/register_lightning_address_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_models.dart';

export 'package:bb_mobile/features/lightning_address/application/application_errors.dart';
export 'package:bb_mobile/features/lightning_address/application/usecases/delete_lightning_address_registration_usecase.dart'
    show DeleteLightningAddressRegistrationCommand;
export 'package:bb_mobile/features/lightning_address/application/usecases/register_lightning_address_usecase.dart'
    show RegisterLightningAddressCommand;
export 'package:bb_mobile/features/lightning_address/domain/lightning_address_models.dart';

class LightningAddressFacade {
  final RegisterLightningAddressUsecase _register;
  final DeleteLightningAddressRegistrationUsecase _deleteRegistration;
  final LookupLightningAddressRegistrationUsecase _lookupRegistration;

  const LightningAddressFacade({
    required this._register,
    required this._deleteRegistration,
    required this._lookupRegistration,
  });

  Future<LightningAddressRegistration> register(
    RegisterLightningAddressCommand command,
  ) {
    return _register.execute(command);
  }

  Future<void> deleteRegistration(
    DeleteLightningAddressRegistrationCommand command,
  ) {
    return _deleteRegistration.execute(command);
  }

  Future<LightningAddressStatus> lookupRegistration({
    required String xprvBase58,
  }) {
    return _lookupRegistration.execute(xprvBase58: xprvBase58);
  }
}
