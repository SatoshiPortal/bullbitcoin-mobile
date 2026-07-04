import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/delete_lightning_address_registration_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lookup_lightning_address_registration_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/register_lightning_address_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';

export 'package:bb_mobile/features/lightning_address/domain/lightning_address_error.dart';
export 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration.dart';

class LightningAddressFacade {
  final RegisterLightningAddressUsecase _register;
  final DeleteLightningAddressRegistrationUsecase _deleteRegistration;
  final LookupLightningAddressRegistrationUsecase _lookupRegistration;

  LightningAddressFacade({
    required BullnymFacade bullnym,
    required NostrIdentityFacade nostrIdentity,
  }) : _register = RegisterLightningAddressUsecase(bullnym, nostrIdentity),
       _deleteRegistration = DeleteLightningAddressRegistrationUsecase(
         bullnym,
         nostrIdentity,
       ),
       _lookupRegistration = LookupLightningAddressRegistrationUsecase(bullnym);

  Future<LightningAddressRegistration> register({
    required String xprvBase58,
    required String nym,
    required String ctDescriptor,
  }) {
    return _register.execute(
      xprvBase58: xprvBase58,
      nym: nym,
      ctDescriptor: ctDescriptor,
    );
  }

  Future<void> deleteRegistration({
    required String xprvBase58,
    required String nym,
  }) {
    return _deleteRegistration.execute(xprvBase58: xprvBase58, nym: nym);
  }

  Future<LightningAddressStatus> lookupRegistration({required String npubHex}) {
    return _lookupRegistration.execute(npubHex: npubHex);
  }
}
