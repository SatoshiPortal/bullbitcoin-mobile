import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_failure.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_nym_validation.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lightning_address_failure_mapping.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';

final class RegisterLightningAddressUsecase {
  final BullnymFacade _bullnym;
  final NostrIdentityFacade _nostrIdentity;

  const RegisterLightningAddressUsecase(this._bullnym, this._nostrIdentity);

  Future<Result<LightningAddressRegistration, LightningAddressFailure>>
  execute({required String nym, required String ctDescriptor}) async {
    final verificationKey = await _nostrIdentity.nip05VerificationPublicKey();
    final String verificationNpubHex;
    switch (verificationKey) {
      case Ok(:final value):
        verificationNpubHex = value.hex;
      case Err():
        return const Err(
          LightningAddressFailure.operation(
            kind: LightningAddressFailureKind.authentication,
            code: 'VerificationKeyUnavailable',
            retryable: true,
          ),
        );
    }

    final validatedNym = validateLightningAddressNym(nym);
    if (validatedNym case Err(:final failure)) return Err(failure);

    final result = await _bullnym.register(
      nym: (validatedNym as Ok<String, LightningAddressFailure>).value,
      ctDescriptor: ctDescriptor,
      verificationNpubHex: verificationNpubHex,
    );
    return switch (result) {
      Ok(:final value) => Ok(
        LightningAddressRegistration(
          nym: value.nym,
          lightningAddress: value.lightningAddress,
        ),
      ),
      Err(:final failure) => Err(mapBullnymToLightningAddressFailure(failure)),
    };
  }
}
