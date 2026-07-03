import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_error.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lightning_address_error_mapping.dart';

class LookupLightningAddressRegistrationUsecase {
  final BullnymFacade _bullnym;

  const LookupLightningAddressRegistrationUsecase(this._bullnym);

  Future<LightningAddressStatus> execute({required String npubHex}) async {
    try {
      final result = await _bullnym.lookupRegistration(npubHex: npubHex);
      return LightningAddressStatus(
        nym: result.nym,
        active: result.active,
        lightningAddress: result.lightningAddress,
      );
    } on BullnymException catch (e) {
      throw mapBullnymToLightningAddressException(e);
    } catch (_) {
      throw const LightningAddressException.unexpected();
    }
  }
}
