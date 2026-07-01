import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_models.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';

class LookupBullnymRegistrationUsecase {
  final BullnymClientPort _client;

  const LookupBullnymRegistrationUsecase(this._client);

  Future<BullnymLookupResult> execute({required String npubHex}) {
    validateBullnymNpubHex(npubHex);
    return _client.lookupRegistration(npubHex: npubHex);
  }
}
