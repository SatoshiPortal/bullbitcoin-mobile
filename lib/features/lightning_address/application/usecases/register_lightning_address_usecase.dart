import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/lightning_address/application/application_errors.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_models.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';

class RegisterLightningAddressCommand {
  final String xprvBase58;
  final String nym;
  final String ctDescriptor;

  const RegisterLightningAddressCommand({
    required this.xprvBase58,
    required this.nym,
    required this.ctDescriptor,
  });
}

class RegisterLightningAddressUsecase {
  final BullnymFacade _bullnym;
  final NostrIdentityFacade _nostrIdentity;

  const RegisterLightningAddressUsecase({
    required this._bullnym,
    required this._nostrIdentity,
  });

  Future<LightningAddressRegistration> execute(
    RegisterLightningAddressCommand command,
  ) async {
    try {
      final signer = _bullnymServerAuthSigner(command.xprvBase58);
      final result = await _bullnym.register(
        signer: signer,
        nym: command.nym,
        ctDescriptor: command.ctDescriptor,
      );
      return LightningAddressRegistration(
        nym: result.nym,
        lightningAddress: result.lightningAddress,
      );
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
