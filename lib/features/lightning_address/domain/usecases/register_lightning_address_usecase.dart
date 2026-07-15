import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_error.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_nym_validation.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lightning_address_error_mapping.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';

class RegisterLightningAddressUsecase {
  final BullnymFacade _bullnym;
  final NostrIdentityFacade _nostrIdentity;

  const RegisterLightningAddressUsecase(this._bullnym, this._nostrIdentity);

  Future<LightningAddressRegistration> execute({
    required String xprvBase58,
    required String nym,
    required String ctDescriptor,
  }) async {
    final normalizedNym = validateLightningAddressNym(nym);

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
      final result = await _bullnym.register(
        signer: signer,
        nym: normalizedNym,
        ctDescriptor: ctDescriptor,
        verificationNpubHex: _nostrIdentity
            .deriveBullnymNip05VerificationPublicKeyFromXprv(xprvBase58),
      );
      return switch (result) {
        Ok(:final value) => LightningAddressRegistration(
          nym: value.nym,
          lightningAddress: value.lightningAddress,
        ),
        Err(:final failure) => throw mapBullnymToLightningAddressException(
          failure,
        ),
      };
    } on LightningAddressException {
      rethrow;
    } catch (_) {
      throw const LightningAddressException.unexpected();
    }
  }
}
