import 'package:bb_mobile/core/utils/result.dart';
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
      return switch (result) {
        Ok(:final value) => LightningAddressStatus(
          nym: value.publicNameStatus?.nym.value ?? value.nym,
          active:
              value.publicNameStatus?.lightningAddressOnline ?? value.active,
          lightningAddress: value.lightningAddress,
          permanentNameStatus: switch (value.publicNameStatus) {
            final status? => LightningAddressPermanentNameStatus(
              nym: status.nym.value,
              lightningAddressOnline: status.lightningAddressOnline,
              quota: LightningAddressPermanentNameQuota(
                used: status.quota.used,
                cap: status.quota.cap,
                remaining: status.quota.remaining,
              ),
            ),
            null => null,
          },
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
