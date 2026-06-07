import 'package:bb_mobile/features/bullnym/application/ports/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_models.dart';

class LookupBullnymRegistrationUsecase {
  final BullnymClientPort _client;

  const LookupBullnymRegistrationUsecase({required this._client});

  Future<BullnymLookupResult> execute({required String npubHex}) {
    return _client.lookupRegistration(npubHex: npubHex);
  }
}
