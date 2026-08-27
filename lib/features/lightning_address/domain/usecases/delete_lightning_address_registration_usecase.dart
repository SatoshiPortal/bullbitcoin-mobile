import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_failure.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_nym_validation.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lightning_address_failure_mapping.dart';

final class DeleteLightningAddressRegistrationUsecase {
  final BullnymFacade _bullnym;

  const DeleteLightningAddressRegistrationUsecase(this._bullnym);

  Future<Result<void, LightningAddressFailure>> execute({
    required String nym,
  }) async {
    final validatedNym = validateLightningAddressNym(nym);
    if (validatedNym case Err(:final failure)) return Err(failure);
    final result = await _bullnym.deleteRegistration(
      (validatedNym as Ok<String, LightningAddressFailure>).value,
    );
    return switch (result) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(mapBullnymToLightningAddressFailure(failure)),
    };
  }
}
