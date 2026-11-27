import 'package:meta/meta.dart';

import '../domain/catalog/market.dart';
import 'kyc_gate_event.dart';

@immutable
sealed class KycGateEffect {
  const KycGateEffect();
}

/// Push the KYC web view over the flow; answer [KycGateReturned].
final class KycGateOpenKyc extends KycGateEffect {
  final Market market;

  const KycGateOpenKyc(this.market);

  @override
  bool operator ==(Object other) =>
      other is KycGateOpenKyc && other.market == market;

  @override
  int get hashCode => Object.hash(KycGateOpenKyc, market);
}
