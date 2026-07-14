import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_error.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_nym_validation.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lightning_address_error_mapping.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';

/// Protocol-level delete. Product UI reaches this only through the wallet-owned
/// deactivation composition, so confidential wallet material never crosses
/// the presentation boundary.
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
      final result = await _bullnym.deleteRegistration(
        signer: signer,
        nym: normalizedNym,
      );
      switch (result) {
        case Ok():
          return;
        case Err(:final failure):
          throw mapBullnymToLightningAddressException(failure);
      }
    } on LightningAddressException {
      rethrow;
    } catch (_) {
      throw const LightningAddressException.unexpected();
    }
  }
}
