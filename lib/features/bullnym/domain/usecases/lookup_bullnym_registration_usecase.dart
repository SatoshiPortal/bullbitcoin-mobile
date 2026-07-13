import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_registration.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';
import 'package:meta/meta.dart';

class LookupBullnymRegistrationUsecase {
  final BullnymClientPort _client;

  const LookupBullnymRegistrationUsecase(this._client);

  @useResult
  Future<Result<BullnymLookupResult, BullnymFailure>> execute({
    required String npubHex,
  }) async {
    switch (validateBullnymNpubHex(npubHex)) {
      case Err(:final failure):
        return Err(failure);
      case Ok():
        return _client.lookupRegistration(npubHex: npubHex);
    }
  }
}
