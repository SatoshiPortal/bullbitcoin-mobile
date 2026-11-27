import 'package:meta/meta.dart';

import '../domain/catalog/kyc_policy.dart';

@immutable
sealed class KycGateEvent {
  const KycGateEvent();
}

final class KycGateOpenPressed extends KycGateEvent {
  const KycGateOpenPressed();
}

/// Back from the KYC web view with the account's groups read again.
final class KycGateReturned extends KycGateEvent {
  final Set<KycGroup> groups;

  const KycGateReturned(this.groups);
}

final class KycGateLeavePressed extends KycGateEvent {
  const KycGateLeavePressed();
}
