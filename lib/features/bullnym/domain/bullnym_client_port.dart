import 'package:bb_mobile/features/bullnym/domain/bullnym_models.dart';

abstract interface class BullnymClientPort {
  Future<BullnymRegisterResult> register(BullnymRegisterRequest request);

  Future<void> deleteRegistration(BullnymDeleteRegistrationRequest request);

  Future<BullnymLookupResult> lookupRegistration({required String npubHex});
}

class BullnymRegisterRequest {
  final String nym;
  final String ctDescriptor;
  final String npubHex;
  final String signatureHex;
  final int timestamp;

  const BullnymRegisterRequest({
    required this.nym,
    required this.ctDescriptor,
    required this.npubHex,
    required this.signatureHex,
    required this.timestamp,
  });
}

class BullnymDeleteRegistrationRequest {
  final String nym;
  final String npubHex;
  final String signatureHex;
  final int timestamp;

  const BullnymDeleteRegistrationRequest({
    required this.nym,
    required this.npubHex,
    required this.signatureHex,
    required this.timestamp,
  });
}
