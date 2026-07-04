import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_error.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_nym_validation.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lightning_address_error_mapping.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';

/// Internal, not exposed by [LightningAddressFacade]: the public surface has no
/// delete affordance yet. Kept (and tested) for a future consumer that wires a
/// delete/deactivate flow; do not treat its existence as a facade capability
/// (R2-P12a).
class DeleteLightningAddressRegistrationUsecase {
  final BullnymFacade _bullnym;
  final NostrIdentityFacade _nostrIdentity;

  const DeleteLightningAddressRegistrationUsecase(
    this._bullnym,
    this._nostrIdentity,
  );

  Future<void> execute({
    required String xprvBase58,
    required String nym,
  }) async {
    validateLightningAddressNym(nym);

    try {
      final signer = BullnymAuthSigner(
        npubHex: _nostrIdentity.deriveBullnymServerAuthPublicKeyFromXprv(
          xprvBase58,
        ),
        signHashHex: (messageHashHex) =>
            _nostrIdentity.signBullnymServerAuthHashFromXprv(
              xprvBase58: xprvBase58,
              messageHashHex: messageHashHex,
            ),
      );
      await _bullnym.deleteRegistration(signer: signer, nym: nym);
    } on BullnymException catch (e) {
      throw mapBullnymToLightningAddressException(e);
    } catch (_) {
      throw const LightningAddressException.unexpected();
    }
  }
}
