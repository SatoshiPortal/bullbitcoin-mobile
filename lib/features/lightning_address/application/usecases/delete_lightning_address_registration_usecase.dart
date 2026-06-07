import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/lightning_address/application/application_errors.dart';
import 'package:bb_mobile/features/lightning_address/application/lightning_address_nym_validation.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';

class DeleteLightningAddressRegistrationCommand {
  final String xprvBase58;
  final String nym;

  const DeleteLightningAddressRegistrationCommand({
    required this.xprvBase58,
    required this.nym,
  });
}

class DeleteLightningAddressRegistrationUsecase {
  final BullnymFacade _bullnym;
  final NostrIdentityFacade _nostrIdentity;

  const DeleteLightningAddressRegistrationUsecase({
    required this._bullnym,
    required this._nostrIdentity,
  });

  Future<void> execute(
    DeleteLightningAddressRegistrationCommand command,
  ) async {
    validateLightningAddressNym(command.nym);

    try {
      final signer = _bullnymServerAuthSigner(command.xprvBase58);
      await _bullnym.deleteRegistration(signer: signer, nym: command.nym);
    } on BullnymException catch (e) {
      throw LightningAddressException.fromBullnym(e);
    } catch (e) {
      throw LightningAddressException.unexpected(e);
    }
  }

  BullnymAuthSigner _bullnymServerAuthSigner(String xprvBase58) {
    return BullnymAuthSigner(
      npubHex: _nostrIdentity.deriveBullnymServerAuthPublicKeyFromXprv(
        xprvBase58,
      ),
      signHashHex: (messageHashHex) =>
          _nostrIdentity.signBullnymServerAuthHashFromXprv(
            xprvBase58: xprvBase58,
            messageHashHex: messageHashHex,
          ),
    );
  }
}
