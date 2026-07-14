import 'package:bb_mobile/features/bullnym/domain/bullnym_public_names.dart';

class BullnymRegisterResult {
  final String nym;
  final String lightningAddress;
  final BullnymQuota? quota;

  const BullnymRegisterResult({
    required this.nym,
    required this.lightningAddress,
    this.quota,
  });
}

class BullnymLookupResult {
  final String nym;
  final bool active;
  final String? lightningAddress;
  final BullnymPublicNameStatus? publicNameStatus;

  const BullnymLookupResult({
    required this.nym,
    required this.active,
    this.lightningAddress,
    this.publicNameStatus,
  });
}
